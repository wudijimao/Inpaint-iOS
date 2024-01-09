//
//  test.metal
//  Inpaint
//
//  Created by wudijimao on 2024/1/6.
//

#include <metal_stdlib>
using namespace metal;
#include <SceneKit/scn_metal>

struct MyNodeBuffer {
    float4x4 modelTransform;
    float4x4 modelViewTransform;
    float4x4 normalTransform;
    float4x4 modelViewProjectionTransform;
};

typedef struct {
    float3 position [[ attribute(SCNVertexSemanticPosition) ]];
} MyVertexInput;

struct SimpleVertex
{
    float4 position [[position]];
};


vertex SimpleVertex myVertex(MyVertexInput in [[ stage_in ]],
                             constant SCNSceneBuffer& scn_frame [[buffer(0)]],
                             constant MyNodeBuffer& scn_node [[buffer(1)]])
{
    SimpleVertex vert;
    vert.position = scn_node.modelViewProjectionTransform * float4(in.position, 1.0);

    return vert;
}

fragment half4 myFragment(SimpleVertex in [[stage_in]])
{
    half4 color;
    color = half4(1.0 ,0.0 ,0.0, 1.0);

    return color;
}


struct OutputVertex {
    float4 position [[position]]; // 顶点位置，使用[[position]]修饰符表示这是输出到屏幕的位置
    float3 normal;                // 顶点法线
    float2 texCoord;              // 纹理坐标
    // 可以根据需要添加其他属性，比如颜色、切线等
};

struct InputVertex {
    float4 position [[attribute(0)]]; // 顶点位置
    float3 normal [[attribute(1)]];   // 顶点法线
    float2 texCoord [[attribute(2)]]; // 纹理坐标
    // 可以根据需要添加其他属性
};

//// 从置换贴图生成模型
//vertex OutputVertex vertex_shader(InputVertex in [[stage_in]],
//                                  texture2d<float> displacementMap [[texture(0)]],
//                                  sampler displacementSampler [[sampler(0)]]) {
//    OutputVertex out;
//
//    // 读取置换贴图中对应位置的值
//    float displacement = displacementMap.sample(displacementSampler, in.texCoord).r;
//
//    // 根据置换值调整顶点位置
//    out.position = in.position + displacement * in.normal;
//
//    // 其他处理
//    // ...
//
//    return out;
//}


// 定义计算核函数
kernel void compute_shader(device float *inputBuffer [[buffer(0)]],
                           device float *outputBuffer [[buffer(1)]],
                           uint id [[thread_position_in_grid]]) {
    // 对每个元素加倍
    outputBuffer[id] = inputBuffer[id] * 2.0;
}

kernel void compute_shader_niubi(texture2d<float, access::read> inputTexture [[texture(0)]],
                           device float *outputBuffer [[buffer(0)]],
                                 device float *texCoordsOutputBuffer [[buffer(1)]],
                           uint2 id [[thread_position_in_grid]]) {
    // 从纹理中读取颜色
    float4 color = inputTexture.read(id);

    int x = id.x;
    int y = id.y;
    int pos = (x + y * inputTexture.get_width()) * 3;
    // 将结果写入输出缓冲区
    outputBuffer[pos] = (id.x / 128.0) - 1.0 ; // 你的处理结果
    outputBuffer[pos + 1] = 1.0 - (id.y / 128.0); // 你的处理结果
    outputBuffer[pos + 2] = color.r;
    
    int texPos = (x + y * inputTexture.get_width()) * 2;
    texCoordsOutputBuffer[texPos] = x / 255.0;
    texCoordsOutputBuffer[texPos + 1] = id.y / 255.0;
}
