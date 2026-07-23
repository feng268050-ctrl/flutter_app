#pragma once

struct Detection {
    float x1, y1, x2, y2;
    float conf;
    int   cls_id;
};
