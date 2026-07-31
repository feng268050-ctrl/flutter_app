#include <opencv2/dnn.hpp>
#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgproc.hpp>

#include <cmath>
#include <cstdlib>
#include <iostream>
#include <limits>
#include <string>
#include <vector>

namespace {

void ScalarBgrToNchwFloat(const cv::Mat& rgb_u8, int imgsz, std::vector<float>& nchw) {
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

void BlobRgbToNchwFloat(const cv::Mat& rgb_u8, int imgsz, std::vector<float>& nchw) {
    cv::Mat blob = cv::dnn::blobFromImage(rgb_u8, 1.0 / 255.0, cv::Size(imgsz, imgsz), cv::Scalar(), false, false,
                                          CV_32F);
    if (!blob.isContinuous()) {
        blob = blob.clone();
    }
    const std::size_t count = blob.total();
    const float* src = blob.ptr<float>();
    nchw.assign(src, src + count);
}

float MaxAbsDiff(const std::vector<float>& a, const std::vector<float>& b) {
    if (a.size() != b.size()) {
        return std::numeric_limits<float>::infinity();
    }
    float max_diff = 0.0F;
    for (std::size_t i = 0; i < a.size(); ++i) {
        max_diff = std::max(max_diff, std::fabs(a[i] - b[i]));
    }
    return max_diff;
}

}  // namespace

int main(int argc, char** argv) {
    const char* image_path = nullptr;
    float tolerance = 1e-5F;
    if (argc > 1) {
        if (std::string(argv[1]).find_first_not_of("0123456789.eE+-") == std::string::npos) {
            tolerance = std::stof(argv[1]);
        } else {
            image_path = argv[1];
            if (argc > 2) {
                tolerance = std::stof(argv[2]);
            }
        }
    }

    const int imgsz = 640;

    cv::Mat bgr;
    if (image_path != nullptr && image_path[0] != '\0') {
        bgr = cv::imread(image_path, cv::IMREAD_COLOR);
        if (bgr.empty()) {
            std::cerr << "Failed to read image: " << image_path << '\n';
            return 2;
        }
        if (bgr.cols != imgsz || bgr.rows != imgsz) {
            cv::resize(bgr, bgr, cv::Size(imgsz, imgsz));
        }
    } else {
        bgr = cv::Mat(imgsz, imgsz, CV_8UC3);
        cv::randu(bgr, cv::Scalar(0, 0, 0), cv::Scalar(255, 255, 255));
    }

    cv::Mat rgb;
    cv::cvtColor(bgr, rgb, cv::COLOR_BGR2RGB);
    if (!rgb.isContinuous()) {
        rgb = rgb.clone();
    }

    std::vector<float> scalar_out;
    std::vector<float> blob_out;
    ScalarBgrToNchwFloat(rgb, imgsz, scalar_out);
    BlobRgbToNchwFloat(rgb, imgsz, blob_out);

    const float max_diff = MaxAbsDiff(scalar_out, blob_out);
    std::cout << "compare_stain_preprocess: elems=" << scalar_out.size()
              << " max_abs_diff=" << max_diff << " tolerance=" << tolerance << '\n';

    if (max_diff > tolerance) {
        std::cerr << "FAIL: scalar vs blobFromImage exceeds tolerance\n";
        return 1;
    }
    std::cout << "PASS\n";
    return 0;
}
