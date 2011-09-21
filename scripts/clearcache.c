#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>

main(int argc,char **argv)
{
        int fd,result;
        printf("Opening: %s\n",argv[1]);
        fd = open(argv[1], O_RDWR);
        printf("FD: %d\n",fd);
        /* result = posix_fadvise(fd, 0, 0, POSIX_FADV_DONTNEED); */
        result = posix_fadvise(fd, 0, 0, 4);
        printf("Result: %d\n",result);
        close(fd);
        _exit(0);
}

