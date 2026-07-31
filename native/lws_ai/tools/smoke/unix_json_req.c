#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/un.h>

int main(int argc, char** argv) {
    if (argc < 3) {
        fprintf(stderr, "usage: %s SOCKPATH JSON_LINE\n", argv[0]);
        return 2;
    }
    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) {
        perror("socket");
        return 1;
    }
    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    if (strlen(argv[1]) >= sizeof(addr.sun_path)) {
        fprintf(stderr, "path too long\n");
        return 1;
    }
    memcpy(addr.sun_path, argv[1], strlen(argv[1]) + 1);
    if (connect(fd, (struct sockaddr*)&addr, sizeof(addr)) != 0) {
        perror("connect");
        return 1;
    }
    size_t len = strlen(argv[2]);
    if (write(fd, argv[2], len) != (ssize_t)len || write(fd, "\n", 1) != 1) {
        perror("write");
        return 1;
    }
    char buf[65536];
    for (;;) {
        ssize_t n = read(fd, buf, sizeof(buf));
        if (n < 0) {
            perror("read");
            return 1;
        }
        if (n == 0) break;
        fwrite(buf, 1, (size_t)n, stdout);
        if (memchr(buf, '\n', (size_t)n)) break;
    }
    close(fd);
    return 0;
}
