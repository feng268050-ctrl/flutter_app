#pragma once

#include <cstdint>
#include <string>
#include <vector>

namespace stream_detect {

/** Minimal RTSP/TCP + RTP/H.264 demux (MediaMTX-compatible interleaved transport). */
class RtspTcpSession {
public:
    bool open(const std::string& rtspUrl);
    void close();
    bool isOpen() const { return socket_fd_ >= 0; }

    /** Returns one Annex-B access unit (may contain multiple NALs). */
    bool readNextAccessUnit(std::vector<uint8_t>& annexBOut, int64_t& ptsUs);

    const std::vector<uint8_t>& sps() const { return sps_; }
    const std::vector<uint8_t>& pps() const { return pps_; }
    int nominalWidth() const { return nominal_width_; }
    int nominalHeight() const { return nominal_height_; }

private:
    bool connectTcp(const std::string& host, int port);
    bool exchangeRtsp(const std::string& url);
    bool sendRequest(const std::string& request);
    bool readResponse(std::string& headersOut, std::string& bodyOut);
    bool readMoreBytes();
    bool consumeInterleavedPacket();
    void handleRtpPacket(const uint8_t* rtp, size_t rtpSize);
    void handleH264RtpPayload(const uint8_t* payload, size_t payloadSize, uint32_t rtpTimestamp);
    void parseSdpSpsPps(const std::string& sdp);
    static bool parseSpsDimensions(const std::vector<uint8_t>& sps, int& width, int& height);

    int socket_fd_ = -1;
    int cseq_ = 1;
    std::string session_id_;
    std::string control_base_;
    std::string stream_url_;
    std::vector<uint8_t> recv_buffer_;
    std::vector<uint8_t> fu_buffer_;
    bool fu_active_ = false;
    uint8_t fu_nal_header_ = 0;
    std::vector<uint8_t> access_unit_;
    std::vector<uint8_t> ready_access_unit_;
    uint32_t last_rtp_timestamp_ = 0;
    bool have_rtp_timestamp_ = false;
    int64_t pts_us_ = 0;
    std::vector<uint8_t> sps_;
    std::vector<uint8_t> pps_;
    int nominal_width_ = 1920;
    int nominal_height_ = 1080;
};

}  // namespace stream_detect
