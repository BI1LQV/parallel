//
// Created by kouushou on 2021/5/12.
//
#include "gemm.h"
#include <cublas.h>

void gemm_cublas(float *A, float *B, float *C, int m, int k, int n,double *time_value){
    float *d_A, *d_B, *d_C;
    size_t size = m * k * sizeof(float);
    cudaMalloc(&d_A, size);
    cudaMemcpy(d_A, A, size,
               cudaMemcpyHostToDevice);

    size = k * n * sizeof(float);
    cudaMalloc(&d_B, size);
    cudaMemcpy(d_B, B, size,
               cudaMemcpyHostToDevice);
// Allocate C in device memory

    size = m * n * sizeof(float);
    cudaMalloc(&d_C, size);



    cublasHandle_t s;
    float al = 1,ve=0;
    cublasCreate_v2(&s);

    for(int i = 0 ; i < WARMUP_TIMES ; ++i){
        cublasSgemm_v2(s,CUBLAS_OP_T,CUBLAS_OP_T,m,n,k,&al,d_A,k,d_B,n,&ve,d_C,n);
    }
    timeval t1,t2;
    cudaDeviceSynchronize();

    for(int i = 0 ; i < BENCH_TIMES ; ++i) {
       // cublasSgemm('N', 'N', m, n, k, 1.0f, d_A, m, d_B, k, 0, d_C, m);

        gettimeofday(&t1, nullptr);
        cublasSgemm_v2(s,CUBLAS_OP_T,CUBLAS_OP_T,m,n,k,&al,d_A,k,d_B,n,&ve,d_C,n);
        cudaDeviceSynchronize();
        gettimeofday(&t2, nullptr);
        *time_value += (t2.tv_sec - t1.tv_sec) + (t2.tv_usec - t1.tv_usec) / 1000000.0;
    }




    cudaMemcpy(C, d_C, size,
               cudaMemcpyDeviceToHost);

    cudaFree(d_A);
    cudaFree(d_B);
    cudaFree(d_C);

}