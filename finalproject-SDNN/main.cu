#include <stdio.h>
#include <stdlib.h>
#include <sys/time.h>
#include <stdbool.h>
#include "mmio.h"
#include "mmiohighlevel.h"
#include <cublas.h>
#define cycleTime 120
#define SPLIT_BLOCK 100
#define SPLIT_THREAD 256
typedef struct
{
	VALUE_TYPE *value;
	int *columnindex;
	int *rowpointer;

} SMatrix;
void toColIndx_(int line, int ld, VALUE_TYPE *val)
{
	VALUE_TYPE *temp = (VALUE_TYPE *)malloc(sizeof(VALUE_TYPE) * line * ld);

	for (int i = 0; i < ld; ++i)
	{
		for (int j = 0; j < line; ++j)
		{
			temp[i * line + j] = val[j * ld + i];
		}
	}
	memcpy(val, temp, sizeof(VALUE_TYPE) * line * ld);
	free(temp);
}

void toRowIndx_(int line, int ld, VALUE_TYPE *val)
{
	VALUE_TYPE *temp = (VALUE_TYPE *)malloc(sizeof(VALUE_TYPE) * line * ld);

	for (int i = 0; i < line; ++i)
	{
		for (int j = 0; j < ld; ++j)
		{
			temp[i * ld + j] = val[j * line + i];
		}
	}
	memcpy(val, temp, sizeof(VALUE_TYPE) * line * ld);
	free(temp);
}
__global__ void relu(VALUE_TYPE *d_C0_value, int mC, int nC)
{
	int i = (blockIdx.x * SPLIT_BLOCK + blockIdx.y) * blockDim.x * blockDim.y + threadIdx.x * SPLIT_THREAD + threadIdx.y;
	VALUE_TYPE tmp = d_C0_value[i];
	if (tmp <= 0)
	{
		tmp = 0;
	}
	else if (tmp >= 32)
	{
		tmp = 32;
	}
	d_C0_value[i] = tmp;
}
int main(int argc, char **argv)
{
	struct timeval t1, t2, t3, t4;
	int size1 = 0;
	int size2 = 0;
	int *tc1;
	int *tc2;
	VALUE_TYPE bias = -0.3000;

	int mA;
	int nA;
	int nnzA;
	int isSymmetricA;
	SMatrix A;

	int mB;
	int nB;
	int nnzB;
	int isSymmetricB;
	SMatrix B[120];

	int mC, nC;
	int nnzC_golden = 0;

	// load A data from file
	gettimeofday(&t3, NULL);
	char filename1[] = "sparse-images-1024.tsv";
	mmio_info(&mA, &nA, &nnzA, &isSymmetricA, filename1);
	A.value = (VALUE_TYPE *)malloc((nnzA) * sizeof(VALUE_TYPE));
	A.columnindex = (int *)malloc((nnzA) * sizeof(int));
	A.rowpointer = (int *)malloc((mA + 1) * sizeof(int));
	mmio_data(A.rowpointer, A.columnindex, A.value, filename1);
	printf("input matrix A: ( %i, %i ) nnz = %i\n", mA, nA, nnzA);
	VALUE_TYPE *A0_dense_value = (VALUE_TYPE *)malloc(mA * nA * sizeof(VALUE_TYPE));
	VALUE_TYPE *d_A0_dense_value;
	cudaMalloc(&d_A0_dense_value, mA * nA * sizeof(VALUE_TYPE));
	memset(A0_dense_value, 0, sizeof(VALUE_TYPE) * mA * nA);
	for (int i = 0; i < mA; i++)
	{
		for (int j = A.rowpointer[i]; j < A.rowpointer[i + 1]; j++)
		{
			A0_dense_value[i * nA + A.columnindex[j]] = A.value[j];
		}
	}
	toColIndx_(60000, 1024, A0_dense_value);

	cudaMemcpy(d_A0_dense_value, A0_dense_value, mA * nA * sizeof(VALUE_TYPE),
			   cudaMemcpyHostToDevice);

	char neuronfile1[] = "neuron1024/n1024-l";
	char neuronfile2[] = ".tsv";
	char filename3[60];

	VALUE_TYPE *d_B_value[120];
	VALUE_TYPE *B_value[120];
	for (int k = 0; k < cycleTime; k++)
	{
		char filenum[5];
		int k1 = k + 1;
		snprintf(filenum, sizeof(filenum), "%d", k1);

		strcpy(filename3, neuronfile1);
		strcat(filename3, filenum);
		strcat(filename3, neuronfile2);

		mmio_info(&mB, &nB, &nnzB, &isSymmetricB, filename3);
		B[k].value = (VALUE_TYPE *)malloc((nnzB) * sizeof(VALUE_TYPE));
		B[k].columnindex = (int *)malloc((nnzB) * sizeof(int));
		B[k].rowpointer = (int *)malloc((mB + 1) * sizeof(int));
		mmio_data(B[k].rowpointer, B[k].columnindex, B[k].value, filename3);

		B_value[k] = (VALUE_TYPE *)malloc(mB * nB * sizeof(VALUE_TYPE));
		memset(B_value[k], 0, sizeof(VALUE_TYPE) * mB * nB);
		for (int i = 0; i < mB; i++)
		{
			for (int j = B[k].rowpointer[i]; j < B[k].rowpointer[i + 1]; j++)
			{
				B_value[k][i * nB + B[k].columnindex[j]] = B[k].value[j];
			}
		}
		for (int x = 0; x < mB; x++)
		{
			for (int y = 0; y < x; y++)
			{
				VALUE_TYPE tmp;
				tmp = B_value[k][y * mB + x];
				B_value[k][y * mB + x] = B_value[k][x * mB + y];
				B_value[k][x * mB + y] = tmp;
			}
		}

		cudaMalloc(&d_B_value[k], sizeof(VALUE_TYPE) * mB * nB);
		cudaMemcpy(d_B_value[k], B_value[k], sizeof(VALUE_TYPE) * mB * nB,
				   cudaMemcpyHostToDevice);

		cudaDeviceSynchronize();
	}
	VALUE_TYPE *biass = (VALUE_TYPE *)malloc(60000 * 1024 * sizeof(VALUE_TYPE));
	for (int i = 0; i < 60000 * 1024; i++)
	{
		biass[i] = bias;
	}
	VALUE_TYPE *d_biass;
	cudaMalloc(&d_biass, 60000 * 1024 * sizeof(VALUE_TYPE));
	cudaMemcpy(d_biass, biass, 60000 * 1024 * sizeof(VALUE_TYPE), cudaMemcpyHostToDevice);
	gettimeofday(&t4, NULL);
	double time_load = (t4.tv_sec - t3.tv_sec) * 1000.0 + (t4.tv_usec - t3.tv_usec) / 1000.0;
	printf("Weight matrix load time: %f ms \n", time_load);

	mC = mA;
	nC = nB;

	VALUE_TYPE *d_C0_value;
	cudaMalloc(&d_C0_value, (mA * nA) * sizeof(VALUE_TYPE));

	gettimeofday(&t3, NULL);
	for (int k = 0; k < cycleTime; k++)
	{
		gettimeofday(&t1, NULL);
		// cudaMemset(d_C0_value, 0, sizeof(VALUE_TYPE) * mC * nC);
		cudaMemcpy(d_C0_value, d_biass, sizeof(VALUE_TYPE) * 60000 * 1024, cudaMemcpyDeviceToDevice);
		// TODO: calc c=a*b
		cublasHandle_t s;
		cublasCreate_v2(&s);
		VALUE_TYPE al = 1, ve = 1;

		cublasSgemm_v2(s,
					   CUBLAS_OP_N, CUBLAS_OP_N,
					   mA, 1024, 1024,
					   &al,
					   d_A0_dense_value, mA,
					   d_B_value[k], mB,
					   &ve,
					   d_C0_value, mA);
		cudaDeviceSynchronize();

		gettimeofday(&t2, NULL);
		double time_gemm = (t2.tv_sec - t1.tv_sec) * 1000.0 + (t2.tv_usec - t1.tv_usec) / 1000.0;

		gettimeofday(&t1, NULL);
		dim3 dimGrid(mC / SPLIT_BLOCK, SPLIT_BLOCK);
		dim3 dimBlock(nC / SPLIT_THREAD, SPLIT_THREAD);
		relu<<<dimGrid, dimBlock>>>(d_C0_value, mC, nC);
		cudaDeviceSynchronize();
		gettimeofday(&t2, NULL);
		double time_biasrelu = (t2.tv_sec - t1.tv_sec) * 1000.0 + (t2.tv_usec - t1.tv_usec) / 1000.0;
		printf("k = %d, GEMM time: %4.5f ms, Bias+ReLU time: %4.5f ms\n",
			   k + 1, time_gemm, time_biasrelu);

		cudaMemcpy(d_A0_dense_value, d_C0_value, (mC * nC) * sizeof(VALUE_TYPE), cudaMemcpyDeviceToDevice);
	}

	gettimeofday(&t4, NULL);
	double time_inference = (t4.tv_sec - t3.tv_sec) * 1000.0 + (t4.tv_usec - t3.tv_usec) / 1000.0;
	printf("Inference time: %f ms \n", time_inference);

	VALUE_TYPE *A0 = (VALUE_TYPE *)malloc(60000 * 1024 * sizeof(VALUE_TYPE));
	cudaMemcpy(A0, d_A0_dense_value, 60000 * 1024 * sizeof(VALUE_TYPE), cudaMemcpyDeviceToHost);
	// TODO: 转置
	toRowIndx_(60000, 1024, A0);
	//  check results
	printf("test\n");
	FILE *fs;
	fs = fopen("sparse-images-1024-1.tsv", "w+");
	for (int i = 0; i < mA; i++)
	{
		int sum = 0;
		for (int j = (i * nA); j < ((i + 1) * nA); j++)
		{
			sum += A0[j];
		}

		if (sum != 0)
		{
			fprintf(fs, "%d\n", i + 1);
		}
	}
	fclose(fs);
	FILE *fp2 = NULL;

	fp2 = fopen("sparse-images-1024-1.tsv", "rb");
	if (fp2 == NULL)
	{
		printf("Error:Open file fail!\n");
	}

	fseek(fp2, 0, SEEK_END);
	size2 = ftell(fp2);
	rewind(fp2);

	tc2 = (int *)malloc(sizeof(int) * size2 / 4);

	int readnum2 = fread(tc2, 4, size2 / 4, fp2);

	fclose(fp2);

	FILE *fp1;

	fp1 = fopen("neuron1024-l120-categories.tsv", "rb");
	if (fp1 == NULL)
	{
		printf("Error:Open file fail!\n");
	}

	fseek(fp1, 0, SEEK_END);
	size1 = ftell(fp1);
	rewind(fp1);

	tc1 = (int *)malloc(sizeof(int) * size1 / 4);

	int readnum1 = fread(tc1, 4, size1 / 4, fp1);

	fclose(fp1);
	int judge = 0;
	for (int i = 0; i < size1 / 4; i++)
	{
		if (tc1[i] - tc2[i] != 0)
		{
			judge++;
		}
	}
	printf("judge:%d\n", judge);
	if (judge == 0)
	{
		printf("CHALLENGE PASSED\n");
	}
	else
	{
		printf("CHALLENGE FAILED\n");
	}

	free(A0);

	return 0;
}
