// Parallel Programming (English), Spring 2021
// Weifeng Liu, China University of Petroleum-Beijing
// Homework 2. *Use ``#pragma omp task''
//             for accelerating tasks of Sort in
//             the function sort_yours().
//             *Try to put the OpenMP directive on
//             top of the functions and see
//             the performance.
//             *Also, try to explore better sorting
//             algorithms and faster ways for optimize sort.

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <omp.h>
int deepStack[10000000] = {0};
int deepStackPointer = 0;
int mergeSortStack[10000000] = {0};
int mergeSortStackPointer = 0;
int cmp(const void *a, const void *b)
{
    return *((int *)a) - *((int *)b);
}
// the reference code of qsort in C library
void qsort_ref(int *array, int len, int (*cmp_in)(const void *, const void *))
{
    qsort(array, len, sizeof(int), cmp_in);
}

void swap(int *a, int *b)
{
    int temp = *b;
    *b = *a;
    *a = temp;
}

int partition(int *array, int start, int end)
{
    int pivot = array[end];
    int i = start;
    for (int j = start; j <= end; j++)
    {
        if (array[j] < pivot)
        {
            swap(&array[i], &array[j]);
            i++;
        }
    }
    swap(&array[i], &array[end]);
    return i;
}



int partition_opti(int *array, int start, int end)
{
    int pivot = array[end];
    int poorGuy=rand()%(end-start)+start;
    swap(&array[end],&array[poorGuy]);
    int i = start;
    for (int j = start; j <= end; j++)
    {
        if (array[j] < pivot)
        {
            swap(&array[i], &array[j]);
            i++;
        }
    }
    swap(&array[i], &array[end]);
    return i;
}

void quicksort_omp(int *array, int start, int end, int *deep)
{
    deepStack[deepStackPointer++] = *deep;
    (*deep)++;
    if (start >= end)
    {
        (*deep)--;
        return;
    }

    int index = partition(array, start, end);

    if (end - start < 1500)
    {
        quicksort_omp(array, start, index - 1, deep);
        quicksort_omp(array, index + 1, end, deep);
    }
    else
    {
        // #pragma omp task
        quicksort_omp(array, start, index - 1, deep);
        // #pragma omp task
        quicksort_omp(array, index + 1, end, deep);
    }
    (*deep)--;
}

// the reference code of a simple quicksort
void quicksort_ref(int *array, int len)
{
    int deep = 0;
    // #pragma omp parallel num_threads(4)
    // #pragma omp single
    

    quicksort_omp(array, 0, len - 1, &deep);
}


void quicksort_opt(int *array, int start, int end, int *deep)
{
    deepStack[deepStackPointer++] = *deep;
    (*deep)++;
    if (start >= end)
    {
        (*deep)--;
        return;
    }

    int index = partition_opti(array, start, end);

    if (end - start < 1500)
    {
        quicksort_opt(array, start, index - 1, deep);
        quicksort_opt(array, index + 1, end, deep);
    }
    else
    {
        #pragma omp task
        quicksort_opt(array, start, index - 1, deep);
        #pragma omp task
        quicksort_opt(array, index + 1, end, deep);
    }
    (*deep)--;
}

// the reference code of a simple quicksort
void quicksort_opti(int *array, int len)
{
    int deep = 0;
    #pragma omp parallel num_threads(12)
    #pragma omp single
    quicksort_opt(array, 0, len - 1, &deep);
}




void mergesort_omp(int *array, int *array_temp, int start, int end, int *deep)
{
    mergeSortStack[mergeSortStackPointer++] = *deep;
    (*deep)++;
    if (start >= end)
    {
        (*deep)--;
        return;
    }

    int mid = (end - start) / 2 + start;
    int start1 = start;
    int end1 = mid;
    int start2 = mid + 1;
    int end2 = end;

    if (end - start < 1500)
    {
        mergesort_omp(array, array_temp, start1, end1, deep);
        mergesort_omp(array, array_temp, start2, end2, deep);
    }
    else
    {
        // #pragma omp task
        mergesort_omp(array, array_temp, start1, end1, deep);
        // #pragma omp task
        mergesort_omp(array, array_temp, start2, end2, deep);
        // #pragma omp taskwait
    }

    int pointer = start;
    while (start1 <= end1 && start2 <= end2)
    {
        if (array[start1] < array[start2])
        {
            array_temp[pointer] = array[start1];
            start1++;
        }
        else
        {
            array_temp[pointer] = array[start2];
            start2++;
        }
        pointer++;
    }

    for (int i = start1; i <= end1; i++)
    {
        array_temp[pointer] = array[i];
        pointer++;
    }

    for (int i = start2; i <= end2; i++)
    {
        array_temp[pointer] = array[i];
        pointer++;
    }

    for (int i = start; i <= end; i++)
        array[i] = array_temp[i];
    (*deep)--;
}

// the reference code of a simple mergesort
void mergesort_ref(int *array, int len)
{
    int *array_temp = (int *)malloc(sizeof(int) * len);
    int deep = 0;
    // #pragma omp parallel num_threads(4)
    // #pragma omp single
    mergesort_omp(array, array_temp, 0, len - 1, &deep);
    free(array_temp);
}

// //insert your code in this function and run
void sort_yours(int *array, int *array_temp, int start, int end)
{
    if (start >= end)
        return;

    int mid = (end - start) / 2 + start;
    int start1 = start;
    int end1 = mid;
    int start2 = mid + 1;
    int end2 = end;

    if (end - start < 1500)
    {
        sort_yours(array, array_temp, start1, end1);
        sort_yours(array, array_temp, start2, end2);
    }
    else
    {
        #pragma omp task
        sort_yours(array, array_temp, start1, end1);
        #pragma omp task
        sort_yours(array, array_temp, start2, end2);
        #pragma omp taskwait
    }
    int pointer = start;
    while (start1 <= end1 && start2 <= end2)
    {
        if (array[start1] < array[start2])
        {
            array_temp[pointer] = array[start1];
            start1++;
        }
        else
        {
            array_temp[pointer] = array[start2];
            start2++;
        }
        pointer++;
    }

    for (int i = start1; i <= end1; i++)
    {
        array_temp[pointer] = array[i];
        pointer++;
    }

    for (int i = start2; i <= end2; i++)
    {
        array_temp[pointer] = array[i];
        pointer++;
    }

    for (int i = start; i <= end; i++)
        array[i] = array_temp[i];
}
void optimize(int *array, int len)
{
    int *array_temp = (int *)malloc(sizeof(int) * len);
    #pragma omp parallel num_threads(12)
    #pragma omp single
    sort_yours(array, array_temp, 0, len - 1);
}
// void insertionSort(int *arr, int left, int right)
// {
//     for (int i = left + 1; i <= right; i++)
//     {
//         int e = arr[i];
//         int j = i;
//         for (; j > left && arr[j - 1] > e; j--)
//         {
//             arr[j] = arr[j - 1];
//         }
//         arr[j] = e;
//     }
// }
// void quicksort_yours(int *array, int start, int end)
// {
//     if (start >= end)
//         return;
//     if (end - start <= 15)
//     {
//         insertionSort(array, start, end);
//         return;
//     }

//     int index = partition(array, start, end);
//     quicksort_yours(array, start, index - 1);
//     quicksort_yours(array, index + 1, end);
// }
// // insert your code in this function and run
// void sort_yours(int *array, int len)
// {
//     quicksort_yours(array, 0, len - 1);
// }

int main()
{
    // set matrix size
    int len = 5000000;
    while (len <= 5000000)
    {
        memset(deepStack, 0, sizeof(int) * 10000000);
        deepStackPointer = 0;
        memset(mergeSortStack, 0, sizeof(int) * 10000000);
        mergeSortStackPointer = 0;
        int *array = (int *)malloc(sizeof(int) * len);
        srand(len);
        for (int i = 0; i < len; ++i)
        {
            array[i] = rand() % len;
            //array[i]=i;
             //array[i]=len-i;
        }

        struct timeval t1, t2;
        int *unorder_array = (int *)malloc(sizeof(int) * len);

        // step 1. test qsort in C library
        // memcpy(unorder_array, array, sizeof(int) * len);

        // gettimeofday(&t1, NULL);
        // qsort_ref(unorder_array, len, cmp);
        // gettimeofday(&t2, NULL);

        // printf("\n%d ,%.5lf,C library,%.5lf\n", len, 1000 * (t2.tv_sec - t1.tv_sec) + (t2.tv_usec - t1.tv_usec) / 1000.0,
        //        len / (1000 * (t2.tv_sec - t1.tv_sec) + (t2.tv_usec - t1.tv_usec) / 1000.0));
        // int pass1 = 1;
        // for (int i = 1; i < len && pass1; ++i)
        // {
        //     if (unorder_array[i] < unorder_array[i - 1])
        //     {
        //         pass1 = 0;
        //     }
        // }
        // if (pass1)
        // {
        //     // printf("qsort in C library passed.\n");
        // }
        // else
        // {
        //     printf("qsort in C library did not passed.\n");
        // }

        //step 2. test a serial quicksort refernce code
        memcpy(unorder_array, array, sizeof(int) * len);

        gettimeofday(&t1, NULL);
        quicksort_ref(unorder_array, len);
        gettimeofday(&t2, NULL);

        printf("\n%d, %.5lf,quicksort_omp,%.5lf\n", len, 1000 * (t2.tv_sec - t1.tv_sec) + (t2.tv_usec - t1.tv_usec) / 1000.0,
               len / (1000 * (t2.tv_sec - t1.tv_sec) + (t2.tv_usec - t1.tv_usec) / 1000.0));
        // int pass2 = 1;
        // for (int i = 1; i < len && pass2; ++i)
        // {
        //     if (unorder_array[i] < unorder_array[i - 1])
        //     {
        //         pass2 = 0;
        //     }
        // }
        // if (pass2)
        // {
        //     // printf("quicksort reference code passed.\n");
        // }
        // else
        // {
        //     printf("quicksort reference code did not passed.\n");
        // }

        //step 3. test a serial mergesort refernce code
        // memcpy(unorder_array, array, sizeof(int) * len);

        // gettimeofday(&t1, NULL);
        // mergesort_ref(unorder_array, len);
        // gettimeofday(&t2, NULL);

        // printf("\n%d,%.5lf,mergesort_omp,%.5lf\n", len, 1000 * (t2.tv_sec - t1.tv_sec) + (t2.tv_usec - t1.tv_usec) / 1000.0,
        //        len / (1000 * (t2.tv_sec - t1.tv_sec) + (t2.tv_usec - t1.tv_usec) / 1000.0));
        // int pass3 = 1;
        // for (int i = 1; i < len && pass3; ++i)
        // {
        //     if (unorder_array[i] < unorder_array[i - 1])
        //     {
        //         pass3 = 0;
        //     }
        // }
        // if (pass3)
        // {
        //     // printf("mergesort reference code passed.\n");
        // }
        // else
        // {
        //     printf("mergesort reference code did not passed.\n");
        // }

        // // // step 4. test your own sorting code
        // memcpy(unorder_array, array, sizeof(int) * len);

        // gettimeofday(&t1, NULL);
        // quicksort_opti(unorder_array, len);
        // gettimeofday(&t2, NULL);

        // printf("\n%d,%.5lf,quicksort_opti, %.5lf\n", len, 1000 * (t2.tv_sec - t1.tv_sec) + (t2.tv_usec - t1.tv_usec) / 1000.0,
        //        len / (1000 * (t2.tv_sec - t1.tv_sec) + (t2.tv_usec - t1.tv_usec) / 1000.0));

        // memcpy(unorder_array, array, sizeof(int) * len);

        // gettimeofday(&t1, NULL);
        // optimize(unorder_array, len);
        // gettimeofday(&t2, NULL);

        // printf("\n%d,%.5lf,merge_opti, %.5lf\n", len, 1000 * (t2.tv_sec - t1.tv_sec) + (t2.tv_usec - t1.tv_usec) / 1000.0,
        //        len / (1000 * (t2.tv_sec - t1.tv_sec) + (t2.tv_usec - t1.tv_usec) / 1000.0));
        // int pass4 = 1;
        // for (int i = 1; i < len && pass4; ++i)
        // {
        //     if (unorder_array[i] < unorder_array[i - 1])
        //     {
        //         pass4 = 0;
        //     }
        // }

        // if (pass4)
        // {
        //     // printf("your sort passed.\n");
        // }
        // else
        // {
        //     printf("your sort did not passed.\n");
        // }

        free(unorder_array);
        free(array);

        len = len * 10;
        for (int i = 0; i < deepStackPointer; i += 1)
        {
            printf("%d,", deepStack[i]);
        }
    }
    return 0;
}