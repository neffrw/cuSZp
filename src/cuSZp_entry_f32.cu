#include "cuSZp_entry_f32.h"
#include "cuSZp_f32.h"
#include <stdio.h>

void SZp_compress_hostptr_f32(float* oriData, unsigned char* cmpBytes, size_t nbEle, size_t* cmpSize, float errorBound)
{
    // Data blocking.
    int bsize = cmp_tblock_size_f32;
    int gsize = (nbEle + bsize * cmp_chunk_f32 - 1) / (bsize * cmp_chunk_f32);
    int cmpOffSize = gsize + 1;
    int pad_nbEle = gsize * bsize * cmp_chunk_f32;

    // Initializing global memory for GPU compression.
    float* d_oriData;
    unsigned char* d_cmpData;
    unsigned int* d_cmpOffset;
    int* d_flag;
    cudaMalloc((void**)&d_oriData, sizeof(float)*pad_nbEle);
    cudaMemcpy(d_oriData, oriData, sizeof(float)*pad_nbEle, cudaMemcpyHostToDevice);
    cudaMalloc((void**)&d_cmpData, sizeof(float)*pad_nbEle);
    cudaMallocManaged((void**)&d_cmpOffset, sizeof(unsigned int)*cmpOffSize);
    cudaMemset(d_cmpOffset, 0, sizeof(unsigned int)*cmpOffSize);
    cudaMalloc((void**)&d_flag, sizeof(int)*cmpOffSize);
    cudaMemset(d_flag, 0, sizeof(int)*cmpOffSize);
    cudaMemset(d_oriData + nbEle, 0, (pad_nbEle - nbEle) * sizeof(float));

    // Initializing CUDA Stream.
    cudaStream_t stream;
    cudaStreamCreate(&stream);

    // cuSZp GPU compression.
    dim3 blockSize(bsize);
    dim3 gridSize(gsize);
    SZp_compress_kernel_f32<<<gridSize, blockSize, 0, stream>>>(d_oriData, d_cmpData, d_cmpOffset, d_flag, errorBound, nbEle);
    cudaDeviceSynchronize();

    // Obtain compression ratio and move data back to CPU.  
    *cmpSize = (size_t)d_cmpOffset[cmpOffSize-1] + (nbEle+31)/32;
    cudaMemcpy(cmpBytes, d_cmpData, *cmpSize*sizeof(unsigned char), cudaMemcpyDeviceToHost);

    // Free memory that is used.
    cudaFree(d_oriData);
    cudaFree(d_cmpData);
    cudaFree(d_cmpOffset);
    cudaFree(d_flag);
    cudaStreamDestroy(stream);
}


void SZp_decompress_hostptr_f32(float* decData, unsigned char* cmpBytes, size_t nbEle, size_t cmpSize, float errorBound)
{
    // Data blocking.
    int bsize = dec_tblock_size_f32;
    int gsize = (nbEle + bsize * dec_chunk_f32 - 1) / (bsize * dec_chunk_f32);
    int cmpOffSize = gsize + 1;
    int pad_nbEle = gsize * bsize * dec_chunk_f32;

    // Initializing global memory for GPU compression.
    float* d_decData;
    unsigned char* d_cmpData;
    unsigned int* d_cmpOffset;
    int* d_flag;
    cudaMalloc((void**)&d_decData, sizeof(float)*pad_nbEle);
    cudaMemset(d_decData, 0, sizeof(float)*pad_nbEle);
    cudaMalloc((void**)&d_cmpData, sizeof(float)*pad_nbEle);
    cudaMemcpy(d_cmpData, cmpBytes, sizeof(unsigned char)*cmpSize, cudaMemcpyHostToDevice);
    cudaMalloc((void**)&d_cmpOffset, sizeof(unsigned int)*cmpOffSize);
    cudaMemset(d_cmpOffset, 0, sizeof(unsigned int)*cmpOffSize);
    cudaMalloc((void**)&d_flag, sizeof(int)*cmpOffSize);
    cudaMemset(d_flag, 0, sizeof(int)*cmpOffSize);

    // Initializing CUDA Stream.
    cudaStream_t stream;
    cudaStreamCreate(&stream);

    // cuSZp GPU compression.
    dim3 blockSize(bsize);
    dim3 gridSize(gsize);
    SZp_decompress_kernel_f32<<<gridSize, blockSize, 0, stream>>>(d_decData, d_cmpData, d_cmpOffset, d_flag, errorBound, nbEle);
    cudaDeviceSynchronize();

    // Move data back to CPU.
    cudaMemcpy(decData, d_decData, sizeof(float)*nbEle, cudaMemcpyDeviceToHost);

    // Free memoy that is used.
    cudaFree(d_decData);
    cudaFree(d_cmpData);
    cudaFree(d_cmpOffset);
    cudaFree(d_flag);
    cudaStreamDestroy(stream);
}


void SZp_compress_deviceptr_f32(float* d_oriData, unsigned char* d_cmpBytes, size_t nbEle, size_t* cmpSize, float errorBound, cudaStream_t stream)
{
    int bsize = cmp_tblock_size_f32;
    int gsize = (nbEle + bsize * cmp_chunk_f32 - 1) / (bsize * cmp_chunk_f32);
    int cmpOffSize = gsize + 1;
    int pad_nbEle = gsize * bsize * cmp_chunk_f32;

    // Initializing global memory for GPU compression.
    unsigned int* d_cmpOffset;
    int* d_flag;
    cudaMallocManaged((void**)&d_cmpOffset, sizeof(unsigned int)*cmpOffSize);
    cudaMemset(d_cmpOffset, 0, sizeof(unsigned int)*cmpOffSize);
    cudaMalloc((void**)&d_flag, sizeof(int)*cmpOffSize);
    cudaMemset(d_flag, 0, sizeof(int)*cmpOffSize);
    // cudaMemset(d_oriData + nbEle, 0, (pad_nbEle - nbEle) * sizeof(float));

    // cuSZp GPU compression.
    dim3 blockSize(bsize);
    dim3 gridSize(gsize);
    SZp_compress_kernel_f32<<<gridSize, blockSize, 0, stream>>>(d_oriData, d_cmpBytes, d_cmpOffset, d_flag, errorBound, nbEle);
    cudaStreamSynchronize(stream);

    // Obtain compression ratio and move data back to CPU.  
    *cmpSize = (size_t)d_cmpOffset[cmpOffSize-1] + (nbEle+31)/32;

    // Free memory that is used.
    cudaFree(d_cmpOffset);
    cudaFree(d_flag);
}


void SZp_decompress_deviceptr_f32(float* d_decData, unsigned char* d_cmpBytes, size_t nbEle, size_t cmpSize, float errorBound, cudaStream_t stream)
{
    // Data blocking.
    int bsize = dec_tblock_size_f32;
    int gsize = (nbEle + bsize * dec_chunk_f32 - 1) / (bsize * dec_chunk_f32);
    int cmpOffSize = gsize + 1;

    // Initializing global memory for GPU compression.
    unsigned int* d_cmpOffset;
    int* d_flag;
    cudaMalloc((void**)&d_cmpOffset, sizeof(unsigned int)*cmpOffSize);
    cudaMemset(d_cmpOffset, 0, sizeof(unsigned int)*cmpOffSize);
    cudaMalloc((void**)&d_flag, sizeof(int)*cmpOffSize);
    cudaMemset(d_flag, 0, sizeof(int)*cmpOffSize);

    // cuSZp GPU compression.
    dim3 blockSize(bsize);
    dim3 gridSize(gsize);
    SZp_decompress_kernel_f32<<<gridSize, blockSize, 0, stream>>>(d_decData, d_cmpBytes, d_cmpOffset, d_flag, errorBound, nbEle);
    cudaStreamSynchronize(stream);

    // Free memoy that is used.
    cudaFree(d_cmpOffset);
    cudaFree(d_flag);
}

#define CUDA_CHECK_RETURN(value) {											\
    cudaError_t _m_cudaStat = value;										\
    if (_m_cudaStat != cudaSuccess) {										\
        fprintf(stderr, "Error %s at line %d in file %s\n",				\
                cudaGetErrorString(_m_cudaStat), __LINE__, __FILE__);		\
        exit(1);															\
    } }

struct toAdd{
    int64_t* d_data;
    int64_t nbEle;
};

cudaHostFn_t addNbEleToCompSize = [](void* userData) {
    struct toAdd* data = (toAdd*)userData;
    int64_t* compsize = data->d_data;
    compsize[0] += (data->nbEle+31)/32;
};

void SZp_compress_deviceptr_f32_async(float* d_oriData, unsigned char* d_cmpBytes, size_t nbEle, int64_t* cmpSize, float errorBound, cudaStream_t stream)
{
    int bsize = cmp_tblock_size_f32;
    int gsize = (nbEle + bsize * cmp_chunk_f32 - 1) / (bsize * cmp_chunk_f32);
    int cmpOffSize = gsize + 1;
    int pad_nbEle = gsize * bsize * cmp_chunk_f32;

    // Initializing global memory for GPU compression.
    unsigned int* d_cmpOffset;
    int* d_flag;
    CUDA_CHECK_RETURN(cudaMallocAsync((void**)&d_cmpOffset, sizeof(unsigned int)*cmpOffSize, stream));
    CUDA_CHECK_RETURN(cudaMallocAsync((void**)&d_flag, sizeof(int)*cmpOffSize, stream));
    CUDA_CHECK_RETURN(cudaMemsetAsync(d_cmpOffset, 0, sizeof(unsigned int)*cmpOffSize, stream));
    CUDA_CHECK_RETURN(cudaMemsetAsync(d_flag, 0, sizeof(int)*cmpOffSize, stream));
    // cudaMemset(d_oriData + nbEle, 0, (pad_nbEle - nbEle) * sizeof(float));

    // cuSZp GPU compression.
    dim3 blockSize(bsize);
    dim3 gridSize(gsize);
    SZp_compress_kernel_f32<<<gridSize, blockSize, 0, stream>>>(d_oriData, d_cmpBytes, d_cmpOffset, d_flag, errorBound, nbEle);

    // Stream sync
    // CUDA_CHECK_RETURN(cudaStreamSynchronize(stream));

    // Memcopy compSize[cmpOffSize-1] back to CPU
    CUDA_CHECK_RETURN(cudaMemcpyAsync(cmpSize, d_cmpOffset + cmpOffSize - 1, sizeof(unsigned int), cudaMemcpyDeviceToHost, stream));

    CUDA_CHECK_RETURN(cudaLaunchHostFunc(stream, addNbEleToCompSize, new toAdd{cmpSize, (int64_t)nbEle}));

    // Free memory that is used.
    CUDA_CHECK_RETURN(cudaFreeAsync(d_cmpOffset, stream));
    CUDA_CHECK_RETURN(cudaFreeAsync(d_flag, stream));
}


// void SZp_decompress_deviceptr_f32_async(float* d_decData, unsigned char* d_cmpBytes, size_t nbEle, size_t cmpSize, float errorBound, cudaStream_t stream)
// {
//     // Data blocking.
//     int bsize = dec_tblock_size_f32;
//     int gsize = (nbEle + bsize * dec_chunk_f32 - 1) / (bsize * dec_chunk_f32);
//     int cmpOffSize = gsize + 1;

//     // Initializing global memory for GPU compression.
//     unsigned int* d_cmpOffset;
//     int* d_flag;
//     cudaMalloc((void**)&d_cmpOffset, sizeof(unsigned int)*cmpOffSize);
//     cudaMemset(d_cmpOffset, 0, sizeof(unsigned int)*cmpOffSize);
//     cudaMalloc((void**)&d_flag, sizeof(int)*cmpOffSize);
//     cudaMemset(d_flag, 0, sizeof(int)*cmpOffSize);

//     // cuSZp GPU compression.
//     dim3 blockSize(bsize);
//     dim3 gridSize(gsize);
//     SZp_decompress_kernel_f32<<<gridSize, blockSize, 0, stream>>>(d_decData, d_cmpBytes, d_cmpOffset, d_flag, errorBound, nbEle);
//     cudaStreamSynchronize(stream);

//     // Free memoy that is used.
//     cudaFree(d_cmpOffset);
//     cudaFree(d_flag);
// }