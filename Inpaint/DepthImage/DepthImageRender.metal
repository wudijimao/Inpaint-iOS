//
//  test.metal
//  Inpaint
//
//  Created by wudijimao on 2024/1/6.
//

#include <metal_stdlib>
using namespace metal;

kernel void compute_shader_niubi(texture2d<float, access::read> inputTexture [[texture(0)]],
                           device float *outputBuffer [[buffer(0)]],
                                 device float *texCoordsOutputBuffer [[buffer(1)]],
                           uint2 position [[thread_position_in_grid]]) {
    // 从纹理中读取颜色
    float4 color = inputTexture.read(position);

    int x = position.x;
    int y = position.y;
    int pos = (x + y * inputTexture.get_width()) * 3;
    // 将结果写入输出缓冲区
    outputBuffer[pos] = (position.x / 128.0) - 1.0 ; // 你的处理结果
    outputBuffer[pos + 1] = 1.0 - (position.y / 128.0); // 你的处理结果
    if (x == 0 || y == 0 || x == 255 || y == 255) {
        // 最边上z设置为0
        if (color.r > 0.5) {
            outputBuffer[pos + 2] = 0;
        } else {
            outputBuffer[pos + 2] = 1.0;
        }
    } else {
        outputBuffer[pos + 2] = color.r;
    }
    
    int texPos = (x + y * inputTexture.get_width()) * 2;
    texCoordsOutputBuffer[texPos] = x / 255.0;
    texCoordsOutputBuffer[texPos + 1] = position.y / 255.0; // 在visionPro上贴图方向是上下颠倒的，或者可能是这张图片的特殊问题，总之先把贴图上下颠倒了一下
}
