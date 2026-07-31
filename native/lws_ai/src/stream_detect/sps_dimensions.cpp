#include "sps_dimensions.h"

namespace stream_detect {

namespace {

bool readBit(const uint8_t* data, size_t size, size_t& bitPos, int& bitOut) {
    if (bitPos / 8 >= size) {
        return false;
    }
    const size_t byteIndex = bitPos / 8;
    const int bitIndex = 7 - static_cast<int>(bitPos % 8);
    bitOut = (data[byteIndex] >> bitIndex) & 1;
    ++bitPos;
    return true;
}

bool readBits(const uint8_t* data, size_t size, size_t& bitPos, int bitCount, int& valueOut) {
    valueOut = 0;
    for (int i = 0; i < bitCount; ++i) {
        int bit = 0;
        if (!readBit(data, size, bitPos, bit)) {
            return false;
        }
        valueOut = (valueOut << 1) | bit;
    }
    return true;
}

int readUe(const uint8_t* data, size_t size, size_t& bitPos) {
    int leadingZeros = 0;
    while (bitPos / 8 < size) {
        int bit = 0;
        if (!readBit(data, size, bitPos, bit)) {
            return 0;
        }
        if (bit) {
            break;
        }
        ++leadingZeros;
    }
    int value = 0;
    for (int i = 0; i < leadingZeros; ++i) {
        int bit = 0;
        if (!readBit(data, size, bitPos, bit)) {
            return 0;
        }
        value = (value << 1) | bit;
    }
    return (1 << leadingZeros) - 1 + value;
}

bool skipScalingList(const uint8_t* data, size_t size, size_t& bitPos, int entries) {
    int lastScale = 8;
    int nextScale = 8;
    for (int j = 0; j < entries; ++j) {
        if (nextScale != 0) {
            const int deltaScale = readUe(data, size, bitPos);
            nextScale = (lastScale + deltaScale + 256) % 256;
        }
        lastScale = (nextScale == 0) ? lastScale : nextScale;
    }
    return true;
}

}  // namespace

bool isPlausibleVideoDimensions(int width, int height) {
    return width >= 320 && height >= 240 && width <= 7680 && height <= 4320;
}

void clampPlausibleVideoDimensions(int& width, int& height) {
    if (!isPlausibleVideoDimensions(width, height)) {
        width = 1920;
        height = 1080;
    }
}

bool parseH264SpsDimensions(const std::vector<uint8_t>& sps, int& width, int& height) {
    if (sps.size() < 4) {
        return false;
    }

    size_t bitPos = 8;  // skip 1-byte NAL header (e.g. 0x67)

    int profileIdc = 0;
    if (!readBits(sps.data(), sps.size(), bitPos, 8, profileIdc)) {
        return false;
    }
    int ignored = 0;
    if (!readBits(sps.data(), sps.size(), bitPos, 6, ignored)) {
        return false;
    }
    if (!readBits(sps.data(), sps.size(), bitPos, 2, ignored)) {
        return false;
    }
    int levelIdc = 0;
    if (!readBits(sps.data(), sps.size(), bitPos, 8, levelIdc)) {
        return false;
    }
    (void)levelIdc;

    readUe(sps.data(), sps.size(), bitPos);  // seq_parameter_set_id

    if (profileIdc == 100 || profileIdc == 110 || profileIdc == 122 || profileIdc == 244 ||
        profileIdc == 44 || profileIdc == 83 || profileIdc == 86 || profileIdc == 118 ||
        profileIdc == 128 || profileIdc == 138 || profileIdc == 139 || profileIdc == 134) {
        const int chromaFormatIdc = readUe(sps.data(), sps.size(), bitPos);
        if (chromaFormatIdc == 3) {
            int separateColourPlaneFlag = 0;
            if (!readBit(sps.data(), sps.size(), bitPos, separateColourPlaneFlag)) {
                return false;
            }
            (void)separateColourPlaneFlag;
        }
        readUe(sps.data(), sps.size(), bitPos);  // bit_depth_luma_minus8
        readUe(sps.data(), sps.size(), bitPos);  // bit_depth_chroma_minus8
        readUe(sps.data(), sps.size(), bitPos);  // qpprime_y_zero_transform_bypass_flag
        const int seqScalingMatrixPresentFlag = readUe(sps.data(), sps.size(), bitPos);
        if (seqScalingMatrixPresentFlag) {
            const int scalingListCount = (chromaFormatIdc != 3) ? 8 : 12;
            for (int i = 0; i < scalingListCount; ++i) {
                int seqScalingListPresentFlag = 0;
                if (!readBit(sps.data(), sps.size(), bitPos, seqScalingListPresentFlag)) {
                    return false;
                }
                if (seqScalingListPresentFlag) {
                    const int entries = (i < 6) ? 16 : 64;
                    if (!skipScalingList(sps.data(), sps.size(), bitPos, entries)) {
                        return false;
                    }
                }
            }
        }
    }

    readUe(sps.data(), sps.size(), bitPos);  // log2_max_frame_num_minus4
    const int picOrderCntType = readUe(sps.data(), sps.size(), bitPos);
    if (picOrderCntType == 0) {
        readUe(sps.data(), sps.size(), bitPos);
    } else if (picOrderCntType == 1) {
        readUe(sps.data(), sps.size(), bitPos);
        const int cycles = readUe(sps.data(), sps.size(), bitPos);
        for (int i = 0; i < cycles; ++i) {
            readUe(sps.data(), sps.size(), bitPos);
        }
        readUe(sps.data(), sps.size(), bitPos);
    }

    readUe(sps.data(), sps.size(), bitPos);  // max_num_ref_frames
    readUe(sps.data(), sps.size(), bitPos);  // gaps_in_frame_num_value_allowed_flag

    const int picWidthInMbs = readUe(sps.data(), sps.size(), bitPos) + 1;
    const int picHeightInMapUnits = readUe(sps.data(), sps.size(), bitPos) + 1;

    int frameMbsOnlyFlag = 0;
    if (!readBit(sps.data(), sps.size(), bitPos, frameMbsOnlyFlag)) {
        return false;
    }
    if (!frameMbsOnlyFlag) {
        int mbAdaptiveFrameFieldFlag = 0;
        if (!readBit(sps.data(), sps.size(), bitPos, mbAdaptiveFrameFieldFlag)) {
            return false;
        }
        (void)mbAdaptiveFrameFieldFlag;
    }

    int direct8x8InferenceFlag = 0;
    if (!readBit(sps.data(), sps.size(), bitPos, direct8x8InferenceFlag)) {
        return false;
    }
    (void)direct8x8InferenceFlag;

    int frameCroppingFlag = 0;
    if (!readBit(sps.data(), sps.size(), bitPos, frameCroppingFlag)) {
        return false;
    }

    int cropLeft = 0;
    int cropRight = 0;
    int cropTop = 0;
    int cropBottom = 0;
    if (frameCroppingFlag) {
        cropLeft = readUe(sps.data(), sps.size(), bitPos);
        cropRight = readUe(sps.data(), sps.size(), bitPos);
        cropTop = readUe(sps.data(), sps.size(), bitPos);
        cropBottom = readUe(sps.data(), sps.size(), bitPos);
    }

    const int cropUnitX = 2;
    const int cropUnitY = 2 * (2 - frameMbsOnlyFlag);

    width = picWidthInMbs * 16 - (cropLeft + cropRight) * cropUnitX;
    height = (2 - frameMbsOnlyFlag) * picHeightInMapUnits * 16 -
             (cropTop + cropBottom) * cropUnitY;

    if (width <= 0 || height <= 0) {
        return false;
    }
    clampPlausibleVideoDimensions(width, height);
    return true;
}

}  // namespace stream_detect
