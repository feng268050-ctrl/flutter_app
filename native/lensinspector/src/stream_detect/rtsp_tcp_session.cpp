#include "rtsp_tcp_session.h"

#include "rtsp_util.h"
#include "sps_dimensions.h"

#ifdef __ANDROID__
#include <android/log.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <sys/socket.h>
#include <unistd.h>
#define SD_LOGI(...) __android_log_print(ANDROID_LOG_INFO, "StreamDetect", __VA_ARGS__)
#define SD_LOGE(...) __android_log_print(ANDROID_LOG_ERROR, "StreamDetect", __VA_ARGS__)
#else
#define SD_LOGI(...) ((void)0)
#define SD_LOGE(...) ((void)0)
#endif

#include <algorithm>
#include <cstring>
#include <sstream>

namespace stream_detect {

namespace {

std::string trim(const std::string& s) {
    size_t start = 0;
    while (start < s.size() && std::isspace(static_cast<unsigned char>(s[start]))) {
        ++start;
    }
    size_t end = s.size();
    while (end > start && std::isspace(static_cast<unsigned char>(s[end - 1]))) {
        --end;
    }
    return s.substr(start, end - start);
}

std::string headerValue(const std::string& headers, const std::string& key) {
    const std::string prefix = key + ":";
    std::istringstream iss(headers);
    std::string line;
    while (std::getline(iss, line)) {
        if (!line.empty() && line.back() == '\r') {
            line.pop_back();
        }
        if (line.size() >= prefix.size() &&
            line.compare(0, prefix.size(), prefix) == 0) {
            return trim(line.substr(prefix.size()));
        }
    }
    return "";
}

}  // namespace

bool RtspTcpSession::connectTcp(const std::string& host, int port) {
#ifdef __ANDROID__
    addrinfo hints{};
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    addrinfo* result = nullptr;
    const std::string portStr = std::to_string(port);
    if (getaddrinfo(host.c_str(), portStr.c_str(), &hints, &result) != 0 || !result) {
        SD_LOGE("rtsp getaddrinfo failed host=%s", host.c_str());
        return false;
    }
    int fd = -1;
    for (addrinfo* rp = result; rp != nullptr; rp = rp->ai_next) {
        fd = static_cast<int>(socket(rp->ai_family, rp->ai_socktype, rp->ai_protocol));
        if (fd < 0) {
            continue;
        }
        if (connect(fd, rp->ai_addr, rp->ai_addrlen) == 0) {
            break;
        }
        ::close(fd);
        fd = -1;
    }
    freeaddrinfo(result);
    if (fd < 0) {
        SD_LOGE("rtsp tcp connect failed host=%s port=%d", host.c_str(), port);
        return false;
    }
    socket_fd_ = fd;
    return true;
#else
    (void)host;
    (void)port;
    return false;
#endif
}

bool RtspTcpSession::sendRequest(const std::string& request) {
#ifdef __ANDROID__
    if (socket_fd_ < 0) {
        return false;
    }
    const char* data = request.c_str();
    size_t remaining = request.size();
    while (remaining > 0) {
        const ssize_t sent = send(socket_fd_, data, remaining, 0);
        if (sent <= 0) {
            return false;
        }
        data += sent;
        remaining -= static_cast<size_t>(sent);
    }
    return true;
#else
    (void)request;
    return false;
#endif
}

bool RtspTcpSession::readResponse(std::string& headersOut, std::string& bodyOut) {
#ifdef __ANDROID__
    headersOut.clear();
    bodyOut.clear();
    while (true) {
        const char* marker = "\r\n\r\n";
        auto it = std::search(recv_buffer_.begin(),
                              recv_buffer_.end(),
                              marker,
                              marker + 4);
        if (it == recv_buffer_.end()) {
            if (!readMoreBytes()) {
                return false;
            }
            continue;
        }
        const size_t headerEnd = static_cast<size_t>(it - recv_buffer_.begin()) + 4;
        headersOut.assign(recv_buffer_.begin(), recv_buffer_.begin() + static_cast<long>(headerEnd));
        recv_buffer_.erase(recv_buffer_.begin(),
                           recv_buffer_.begin() + static_cast<long>(headerEnd));
        const std::string contentLengthStr = headerValue(headersOut, "Content-Length");
        if (contentLengthStr.empty()) {
            return true;
        }
        const size_t contentLength = static_cast<size_t>(std::stoul(contentLengthStr));
        while (recv_buffer_.size() < contentLength) {
            if (!readMoreBytes()) {
                return false;
            }
        }
        bodyOut.assign(recv_buffer_.begin(),
                       recv_buffer_.begin() + static_cast<long>(contentLength));
        recv_buffer_.erase(recv_buffer_.begin(),
                           recv_buffer_.begin() + static_cast<long>(contentLength));
        return true;
    }
#else
    (void)headersOut;
    (void)bodyOut;
    return false;
#endif
}

bool RtspTcpSession::readMoreBytes() {
#ifdef __ANDROID__
    uint8_t tmp[4096];
    const ssize_t n = recv(socket_fd_, tmp, sizeof(tmp), 0);
    if (n <= 0) {
        return false;
    }
    recv_buffer_.insert(recv_buffer_.end(), tmp, tmp + n);
    return true;
#else
    return false;
#endif
}

bool RtspTcpSession::parseSpsDimensions(const std::vector<uint8_t>& sps, int& width, int& height) {
    return parseH264SpsDimensions(sps, width, height);
}

void RtspTcpSession::parseSdpSpsPps(const std::string& sdp) {
    std::istringstream iss(sdp);
    std::string line;
    while (std::getline(iss, line)) {
        if (!line.empty() && line.back() == '\r') {
            line.pop_back();
        }
        if (line.compare(0, 10, "a=control:") == 0) {
            control_base_ = line.substr(10);
        }
        const std::string key = "a=fmtp:";
        if (line.compare(0, key.size(), key) != 0) {
            continue;
        }
        const size_t sprop = line.find("sprop-parameter-sets=");
        if (sprop == std::string::npos) {
            continue;
        }
        std::string values = line.substr(sprop + 21);
        const size_t comma = values.find(',');
        if (comma == std::string::npos) {
            continue;
        }
        base64Decode(values.substr(0, comma), sps_);
        base64Decode(values.substr(comma + 1), pps_);
        if (!sps_.empty()) {
            parseSpsDimensions(sps_, nominal_width_, nominal_height_);
        }
    }
}

bool RtspTcpSession::exchangeRtsp(const std::string& url) {
    std::ostringstream describe;
    describe << "DESCRIBE " << url << " RTSP/1.0\r\n"
             << "CSeq: " << cseq_++ << "\r\n"
             << "Accept: application/sdp\r\n"
             << "User-Agent: lws-stream-detect\r\n\r\n";
    if (!sendRequest(describe.str())) {
        return false;
    }
    std::string headers;
    std::string body;
    if (!readResponse(headers, body)) {
        return false;
    }
    if (headers.find("200") == std::string::npos) {
        SD_LOGE("rtsp DESCRIBE failed headers=%s", headers.c_str());
        return false;
    }
    parseSdpSpsPps(body);

    std::string control = control_base_.empty() ? "trackID=0" : control_base_;
    if (control.find("rtsp://") == std::string::npos) {
        if (!control.empty() && control[0] == '/') {
            control_base_ = url + control;
        } else {
            control_base_ = url + "/" + control;
        }
    } else {
        control_base_ = control;
    }

    std::ostringstream setup;
    setup << "SETUP " << control_base_ << " RTSP/1.0\r\n"
          << "CSeq: " << cseq_++ << "\r\n"
          << "Transport: RTP/AVP/TCP;unicast;interleaved=0-1\r\n\r\n";
    if (!sendRequest(setup.str())) {
        return false;
    }
    if (!readResponse(headers, body)) {
        return false;
    }
    session_id_ = headerValue(headers, "Session");
    const size_t semi = session_id_.find(';');
    if (semi != std::string::npos) {
        session_id_ = session_id_.substr(0, semi);
    }
    if (session_id_.empty()) {
        SD_LOGE("rtsp SETUP missing Session");
        return false;
    }

    std::ostringstream play;
    play << "PLAY " << url << " RTSP/1.0\r\n"
         << "CSeq: " << cseq_++ << "\r\n"
         << "Session: " << session_id_ << "\r\n"
         << "Range: npt=0.000-\r\n\r\n";
    if (!sendRequest(play.str())) {
        return false;
    }
    if (!readResponse(headers, body)) {
        return false;
    }
    SD_LOGI("rtsp session ready url=%s %dx%d", url.c_str(), nominal_width_, nominal_height_);
    return true;
}

bool RtspTcpSession::open(const std::string& rtspUrl) {
    close();
    ParsedRtspUrl parsed;
    if (!parseRtspUrl(rtspUrl, parsed)) {
        SD_LOGE("rtsp invalid url=%s", rtspUrl.c_str());
        return false;
    }
    stream_url_ = rtspUrl;
    if (!connectTcp(parsed.host, parsed.port)) {
        return false;
    }
    if (!exchangeRtsp(rtspUrl)) {
        close();
        return false;
    }
    return true;
}

void RtspTcpSession::close() {
#ifdef __ANDROID__
    if (socket_fd_ >= 0 && !session_id_.empty() && !stream_url_.empty()) {
        std::ostringstream tear;
        tear << "TEARDOWN " << stream_url_ << " RTSP/1.0\r\n"
             << "CSeq: " << cseq_++ << "\r\n"
             << "Session: " << session_id_ << "\r\n\r\n";
        sendRequest(tear.str());
    }
    if (socket_fd_ >= 0) {
        ::close(socket_fd_);
        socket_fd_ = -1;
    }
#endif
    recv_buffer_.clear();
    fu_buffer_.clear();
    access_unit_.clear();
    ready_access_unit_.clear();
    session_id_.clear();
    fu_active_ = false;
    have_rtp_timestamp_ = false;
}

void RtspTcpSession::handleH264RtpPayload(const uint8_t* payload,
                                          size_t payloadSize,
                                          uint32_t rtpTimestamp) {
    if (payloadSize == 0) {
        return;
    }
    if (have_rtp_timestamp_ && rtpTimestamp != last_rtp_timestamp_ && !access_unit_.empty()) {
        ready_access_unit_.swap(access_unit_);
        access_unit_.clear();
    }
    last_rtp_timestamp_ = rtpTimestamp;
    have_rtp_timestamp_ = true;
    pts_us_ = static_cast<int64_t>(rtpTimestamp) * 1000000LL / 90000LL;

    const uint8_t nalType = payload[0] & 0x1F;
    if (nalType == 24) {
        size_t offset = 1;
        while (offset + 2 <= payloadSize) {
            const uint16_t nalSize =
                (static_cast<uint16_t>(payload[offset]) << 8) | payload[offset + 1];
            offset += 2;
            if (nalSize == 0 || offset + nalSize > payloadSize) {
                break;
            }
            appendAnnexBStartCode(access_unit_);
            access_unit_.insert(access_unit_.end(), payload + offset, payload + offset + nalSize);
            offset += nalSize;
        }
        return;
    }
    if (nalType >= 1 && nalType <= 23) {
        appendAnnexBStartCode(access_unit_);
        access_unit_.insert(access_unit_.end(), payload, payload + payloadSize);
        return;
    }
    if (nalType != 28 || payloadSize < 2) {
        return;
    }
    const uint8_t fuHeader = payload[1];
    const bool start = (fuHeader & 0x80) != 0;
    const bool end = (fuHeader & 0x40) != 0;
    if (start) {
        fu_active_ = true;
        fu_nal_header_ = static_cast<uint8_t>((payload[0] & 0xE0) | (fuHeader & 0x1F));
        fu_buffer_.clear();
        appendAnnexBStartCode(fu_buffer_);
        fu_buffer_.push_back(fu_nal_header_);
        fu_buffer_.insert(fu_buffer_.end(), payload + 2, payload + payloadSize);
    } else if (fu_active_) {
        fu_buffer_.insert(fu_buffer_.end(), payload + 2, payload + payloadSize);
        if (end) {
            access_unit_.insert(access_unit_.end(), fu_buffer_.begin(), fu_buffer_.end());
            fu_buffer_.clear();
            fu_active_ = false;
        }
    }
}

void RtspTcpSession::handleRtpPacket(const uint8_t* rtp, size_t rtpSize) {
    if (rtpSize < 12) {
        return;
    }
    const uint8_t version = rtp[0] >> 6;
    if (version != 2) {
        return;
    }
    const bool extension = (rtp[0] >> 4) & 1;
    const uint8_t csrcCount = rtp[0] & 0x0F;
    size_t headerSize = 12 + csrcCount * 4;
    if (extension) {
        if (rtpSize < headerSize + 4) {
            return;
        }
        const uint16_t extLen = (static_cast<uint16_t>(rtp[headerSize + 2]) << 8) | rtp[headerSize + 3];
        headerSize += 4 + extLen * 4;
    }
    if (rtpSize <= headerSize) {
        return;
    }
    const uint32_t timestamp = (static_cast<uint32_t>(rtp[4]) << 24) |
                               (static_cast<uint32_t>(rtp[5]) << 16) |
                               (static_cast<uint32_t>(rtp[6]) << 8) |
                               static_cast<uint32_t>(rtp[7]);
    handleH264RtpPayload(rtp + headerSize, rtpSize - headerSize, timestamp);
}

bool RtspTcpSession::consumeInterleavedPacket() {
    if (recv_buffer_.size() < 4) {
        return false;
    }
    if (recv_buffer_[0] != '$') {
        return false;
    }
    const uint8_t channel = recv_buffer_[1];
    const uint16_t packetSize =
        (static_cast<uint16_t>(recv_buffer_[2]) << 8) | recv_buffer_[3];
    if (recv_buffer_.size() < 4 + packetSize) {
        return false;
    }
    if (channel == 0) {
        handleRtpPacket(recv_buffer_.data() + 4, packetSize);
    }
    recv_buffer_.erase(recv_buffer_.begin(), recv_buffer_.begin() + 4 + packetSize);
    return true;
}

bool RtspTcpSession::readNextAccessUnit(std::vector<uint8_t>& annexBOut, int64_t& ptsUs) {
#ifdef __ANDROID__
    annexBOut.clear();
    for (int attempt = 0; attempt < 500; ++attempt) {
        if (!ready_access_unit_.empty()) {
            annexBOut.swap(ready_access_unit_);
            ptsUs = pts_us_;
            return true;
        }
        if (!access_unit_.empty()) {
            annexBOut.swap(access_unit_);
            ptsUs = pts_us_;
            return true;
        }
        while (!recv_buffer_.empty() && recv_buffer_[0] == '$') {
            if (!consumeInterleavedPacket()) {
                break;
            }
            if (!ready_access_unit_.empty()) {
                annexBOut.swap(ready_access_unit_);
                ptsUs = pts_us_;
                return true;
            }
            if (!access_unit_.empty()) {
                annexBOut.swap(access_unit_);
                ptsUs = pts_us_;
                return true;
            }
        }
        if (!readMoreBytes()) {
            SD_LOGE("readNextAccessUnit: tcp recv failed buffer=%zu", recv_buffer_.size());
            return false;
        }
    }
    SD_LOGE("readNextAccessUnit: no access unit after polling buffer=%zu", recv_buffer_.size());
    return false;
#else
    (void)annexBOut;
    ptsUs = 0;
    return false;
#endif
}

}  // namespace stream_detect
