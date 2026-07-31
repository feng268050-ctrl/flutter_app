#include "stain_preprocess.h"

#include <opencv2/dnn.hpp>
#include <opencv2/imgproc.hpp>

namespace stain_preprocess {

#if defined(LENS_STAIN_PREPROCESS_SCALAR) && LENS_STAIN_PREPROCESS_SCALAR
static void BgrToNchwFloat(const cv::Mat& rgb_u8, int imgsz, std::vector<float>& nchw) {
    const int plane = imgsz * imgsz;
    nchw.resize(static_cast<std::size_t>(3 * plane));
    for (int y = 0; y < imgsz; ++y) {
        const auto* row = rgb_u8.ptr<cv::Vec3b>(y);
        for (int x = 0; x < imgsz; ++x) {
            const int idx = y * imgsz + x;
            nchw[static_cast<std::size_t>(idx)] = row[x][0] / 255.0F;
            nchw[static_cast<std::size_t>(plane + idx)] = row[x][1] / 255.0F;
            nchw[static_cast<std::size_t>(2 * plane + idx)] = row[x][2] / 255.0F;
        }
    }
}
#else
static void RgbToNchwFloat(const cv::Mat& rgb_u8, int imgsz, std::vector<float>& nchw) {
    cv::Mat blob = cv::dnn::blobFromImage(rgb_u8, 1.0 / 255.0, cv::Size(imgsz, imgsz), cv::Scalar(), false,
                                          false, CV_32F);
    if (!blob.isContinuous()) {
        blob = blob.clone();
    }
    const std::size_t count = blob.total();
    const float* src = blob.ptr<float>();
    nchw.assign(src, src + count);
}
#endif

static void FillNchw(const cv::Mat& rgb_u8, int imgsz, std::vector<float>& nchw) {
#if defined(LENS_STAIN_PREPROCESS_SCALAR) && LENS_STAIN_PREPROCESS_SCALAR
    BgrToNchwFloat(rgb_u8, imgsz, nchw);
#else
    RgbToNchwFloat(rgb_u8, imgsz, nchw);
#endif
}

bool PreprocessRoiResize(const cv::Mat& bgr, int imgsz, Output& out, std::string& err) {
    if (bgr.empty()) {
        err = "empty image";
        return false;
    }
    if (bgr.cols < kRoiX + kRoiSize || bgr.rows < kRoiY + kRoiSize) {
        err = "image smaller than fixed ROI";
        return false;
    }
    cv::Mat roi = bgr(cv::Rect(kRoiX, kRoiY, kRoiSize, kRoiSize));
    cv::Mat resized;
    cv::resize(roi, resized, cv::Size(imgsz, imgsz), 0, 0, cv::INTER_LINEAR);
    cv::cvtColor(resized, out.rgb_u8, cv::COLOR_BGR2RGB);
    if (!out.rgb_u8.isContinuous()) {
        out.rgb_u8 = out.rgb_u8.clone();
    }
    FillNchw(out.rgb_u8, imgsz, out.nchw_f32);
    return true;
}

bool PreprocessLetterbox(const cv::Mat& bgr, int imgsz, Output& out, float& scale, int& pad_w, int& pad_h,
                         std::string& err) {
    if (bgr.empty()) {
        err = "empty image";
        return false;
    }
    const int h = bgr.rows;
    const int w = bgr.cols;
    scale = std::min(static_cast<float>(imgsz) / static_cast<float>(h),
                     static_cast<float>(imgsz) / static_cast<float>(w));
    const int nw = static_cast<int>(std::round(static_cast<float>(w) * scale));
    const int nh = static_cast<int>(std::round(static_cast<float>(h) * scale));
    pad_w = (imgsz - nw) / 2;
    pad_h = (imgsz - nh) / 2;
    cv::Mat resized;
    cv::resize(bgr, resized, cv::Size(nw, nh), 0, 0, cv::INTER_LINEAR);
    cv::Mat canvas(imgsz, imgsz, CV_8UC3, cv::Scalar(114, 114, 114));
    resized.copyTo(canvas(cv::Rect(pad_w, pad_h, nw, nh)));
    cv::cvtColor(canvas, out.rgb_u8, cv::COLOR_BGR2RGB);
    if (!out.rgb_u8.isContinuous()) {
        out.rgb_u8 = out.rgb_u8.clone();
    }
    FillNchw(out.rgb_u8, imgsz, out.nchw_f32);
    return true;
}

}  // namespace stain_preprocess
