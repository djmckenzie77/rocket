////////////////////////////////////////////////////////////////////////////////
// main.cpp
// Mark Setchell
//
// Read video stream from "raspivid" and write (independently) to both disk file
// and stdout - for onward netcatting to another host.
//
// Compiles with:
//    g++ main.cpp -o main -lpthread
//
// Run on Raspberry Pi with:
//    raspivid -t 0 -md 5 -fps 30 -o - | ./main video.h264 | netcat -v 192.168.0.8 5000
//
// Receive on other host with:
//    netcat -l -p 5000 | mplayer -vf scale -zoom -xy 1280 -fps 30 -cache-min 50 -cache 1024 -
////////////////////////////////////////////////////////////////////////////////
#include <iostream>
#include <chrono>
#include <thread>
#include <vector>
#include <unistd.h>
#include <atomic>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <fcntl.h>
#include <string.h>

#define BUFSZ    65536
#define NBUFS    64

class Buffer{
   public:
   int bytes=0;
   std::atomic<int> NeedsWriteToDisk{0};
   std::atomic<int> NeedsWriteToFifo{0};
   unsigned char data[BUFSZ];
};

std::vector<Buffer> buffers(NBUFS);

FILE *open_filename(char *filename)
{
   FILE *new_handle = NULL;

   if (filename)
   {
      bool bNetwork = false;
      int sfd = -1, socktype;

      if(!strncmp("tcp://", filename, 6))
      {
         bNetwork = true;
         socktype = SOCK_STREAM;
      }
      else if(!strncmp("udp://", filename, 6))
      {
         bNetwork = true;
         socktype = SOCK_DGRAM;
      }

      if(bNetwork)
      {
         unsigned short port;
         filename += 6;
         char *colon;
         if(NULL == (colon = strchr(filename, ':')))
         {
            fprintf(stderr, "%s is not a valid IPv4:port, use something like tcp://1.2.3.4:1234 or udp://1.2.3.4:1234\n",
                    filename);
            exit(132);
         }
         if(1 != sscanf(colon + 1, "%hu", &port))
         {
            fprintf(stderr,
                    "Port parse failed. %s is not a valid network file name, use something like tcp://1.2.3.4:1234 or udp://1.2.3.4:1234\n",
                    filename);
            exit(133);
         }
         char chTmp = *colon;
         *colon = 0;

         struct sockaddr_in saddr={};
         saddr.sin_family = AF_INET;
         saddr.sin_port = htons(port);
         if(0 == inet_aton(filename, &saddr.sin_addr))
         {
            fprintf(stderr, "inet_aton failed. %s is not a valid IPv4 address\n",
                    filename);
            exit(134);
         }
         *colon = chTmp;

         if(0 <= (sfd = socket(AF_INET, socktype, 0)))
         {
           fprintf(stderr, "Connecting to %s:%hu...", inet_ntoa(saddr.sin_addr), port);

           int iTmp = 1;
           while ((-1 == (iTmp = connect(sfd, (struct sockaddr *) &saddr, sizeof(struct sockaddr_in)))) && (EINTR == errno))
             ;
           if (iTmp < 0)
             fprintf(stderr, "error: %s\n", strerror(errno));
           else
             fprintf(stderr, "connected, sending video...\n");
         }
         else
           fprintf(stderr, "Error creating socket: %s\n", strerror(errno));

         if (sfd >= 0)
            new_handle = fdopen(sfd, "w");
      }
      else
      {
         new_handle = fopen(filename, "wb");
      }
   }

   return new_handle;
}

////////////////////////////////////////////////////////////////////////////////
// This is the DiskWriter thread.
// It loops through all the buffers waiting in turn for each one to become ready
// then writes it to disk and marks the buffer as written before moving to next
// buffer.
////////////////////////////////////////////////////////////////////////////////
void DiskWriter(char* filename){
   int bufIndex=0;

   // Open output file
   int fd=open(filename,O_CREAT|O_WRONLY|O_TRUNC,S_IRUSR|S_IWUSR|S_IRGRP|S_IWGRP);
   if(fd==-1)
   {
      std::cerr << "ERROR: Unable to open output file" << std::endl;
      exit(EXIT_FAILURE);
   }

   bool Error=false;
   while(!Error){

      // Wait for buffer to be filled by main thread
      while(buffers[bufIndex].NeedsWriteToDisk!=1){
   //      std::this_thread::sleep_for(std::chrono::milliseconds(1));
      }

      // Write to disk
      int bytesToWrite=buffers[bufIndex].bytes;
      int bytesWritten=write(fd,reinterpret_cast<unsigned char*>(&buffers[bufIndex].data),bytesToWrite);
      if(bytesWritten!=bytesToWrite){
         std::cerr << "ERROR: Unable to write to disk" << std::endl;
         exit(EXIT_FAILURE);
      }

      // Mark buffer as written
      buffers[bufIndex].NeedsWriteToDisk=0;

      // Move to next buffer
      bufIndex=(bufIndex+1)%NBUFS;
   }
}

////////////////////////////////////////////////////////////////////////////////
// This is the NbWriter thread.
// It loops through all the buffers waiting in turn for each one to become ready
// then writes it to the Fifo, flushes it for reduced lag, and marks the buffer
// as written before moving to next one. Errors are ignored.
////////////////////////////////////////////////////////////////////////////////
void NbWriter(char* filename_nb){
   int bufIndex=0;

   bool Error=false;
   FILE *nb_handle = open_filename(filename_nb);
   while(!Error){

      // Wait for buffer to be filled by main thread
      while(buffers[bufIndex].NeedsWriteToFifo!=1){
    //     std::this_thread::sleep_for(std::chrono::milliseconds(1));
      }

      // Write to fifo
      int bytesToWrite=buffers[bufIndex].bytes;
      int bytesWritten=fwrite(reinterpret_cast<unsigned char*>(&buffers[bufIndex].data), 1,
                              bytesToWrite, nb_handle);
      if(bytesWritten!=bytesToWrite){
         std::cerr << "ERROR: Unable to fully write to nb_handle" << std::endl;
      }
      // Try to reduce lag
      fflush(nb_handle);

      // Mark buffer as written
      buffers[bufIndex].NeedsWriteToFifo=0;

      // Move to next buffer
      bufIndex=(bufIndex+1)%NBUFS;
   }
}

int main(int argc, char *argv[])
{   
   int bufIndex=0;

   if(argc!=3){
      std::cerr << "ERROR: Usage " << argv[0] << " <filename> <filename_nb>" << std::endl;
      exit(EXIT_FAILURE);
   }
   char * filename = argv[1];
   char * filename_nb = argv[2];

   // Start disk and fifo writing threads in parallel
   std::thread tDiskWriter(DiskWriter, filename);
   std::thread tNbWriter(NbWriter, filename_nb);

   bool Error=false;
   // Continuously fill buffers from "raspivid" on stdin. Mark as full and
   // needing output to disk and fifo before moving to next buffer.
   while(!Error)
   {
      // Check disk writer is not behind before re-using buffer
      if(buffers[bufIndex].NeedsWriteToDisk==1){
         std::cerr << "ERROR: Disk writer is behind by " << NBUFS << " buffers" << std::endl;
      }

      // Check fifo writer is not behind before re-using buffer
      if(buffers[bufIndex].NeedsWriteToFifo==1){
         std::cerr << "ERROR: Fifo writer is behind by " << NBUFS << " buffers" << std::endl;
      }

      // Read from STDIN till buffer is pretty full
      int bytes;
      int totalBytes=0;
      int bytesToRead=BUFSZ;
      unsigned char* ptr=reinterpret_cast<unsigned char*>(&buffers[bufIndex].data);
      while(totalBytes<(BUFSZ*.75)){
         bytes = read(STDIN_FILENO,ptr,bytesToRead);
         if(bytes<=0){
            Error=true;
            break;
         }
         ptr+=bytes;
         totalBytes+=bytes;
         bytesToRead-=bytes;
      }

      // Signal buffer ready for writing
      buffers[bufIndex].bytes=totalBytes;
      buffers[bufIndex].NeedsWriteToDisk=1;
      buffers[bufIndex].NeedsWriteToFifo=1;

      // Move to next buffer
      bufIndex=(bufIndex+1)%NBUFS;
   }
}
