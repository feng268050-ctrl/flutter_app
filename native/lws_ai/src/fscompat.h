#pragma once

#include <ctime>
#include <string>
#include <vector>

#include <dirent.h>
#include <sys/stat.h>
#include <unistd.h>

// POSIX filesystem helpers (NDK r18b has no <filesystem>).
namespace fscompat {

inline void makedirs(const std::string& path) {
    std::string tmp;
    for (char c : path) {
        tmp += c;
        if (c == '/')
            ::mkdir(tmp.c_str(), 0755);
    }
    ::mkdir(tmp.c_str(), 0755);
}

inline std::string join(const std::string& a, const std::string& b) {
    if (a.empty()) return b;
    if (a.back() == '/') return a + b;
    return a + "/" + b;
}

inline bool exists(const std::string& path) {
    struct stat st;
    return ::stat(path.c_str(), &st) == 0;
}

inline bool is_absolute(const std::string& path) {
    return !path.empty() && path[0] == '/';
}

inline std::string parent_path(const std::string& path) {
    auto pos = path.rfind('/');
    if (pos == std::string::npos) return ".";
    if (pos == 0) return "/";
    return path.substr(0, pos);
}

struct DirEntry {
    std::string path;
    time_t      mtime;
};

inline std::vector<DirEntry> list_files(const std::string& dir) {
    std::vector<DirEntry> out;
    DIR* d = ::opendir(dir.c_str());
    if (!d) return out;
    struct dirent* ent;
    while ((ent = ::readdir(d)) != nullptr) {
        if (ent->d_name[0] == '.') continue;
        std::string full = join(dir, ent->d_name);
        struct stat st;
        if (::stat(full.c_str(), &st) == 0 && S_ISREG(st.st_mode))
            out.push_back({full, st.st_mtime});
    }
    ::closedir(d);
    return out;
}

inline void remove_file(const std::string& path) {
    ::unlink(path.c_str());
}

} // namespace fscompat
