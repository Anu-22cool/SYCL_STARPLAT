// FOR BC: nvcc bc_dsl_v2.cu -arch=sm_60 -std=c++14 -rdc=true # HW must support CC 6.0+ Pascal or after
#include "k-core.h"

void k_core(graph& g,int k)

{
  // CSR BEGIN
  int V = g.num_nodes();
  int E = g.num_edges();

  printf("#nodes:%d\n",V);
  printf("#edges:%d\n",E);
  int* edgeLen = g.getEdgeLen();

  int *h_meta;
  int *h_data;
  int *h_src;
  int *h_weight;
  int *h_rev_meta;

  h_meta = (int *)malloc( (V+1)*sizeof(int));
  h_data = (int *)malloc( (E)*sizeof(int));
  h_src = (int *)malloc( (E)*sizeof(int));
  h_weight = (int *)malloc( (E)*sizeof(int));
  h_rev_meta = (int *)malloc( (V+1)*sizeof(int));

  for(int i=0; i<= V; i++) {
    int temp = g.indexofNodes[i];
    h_meta[i] = temp;
    temp = g.rev_indexofNodes[i];
    h_rev_meta[i] = temp;
  }

  for(int i=0; i< E; i++) {
    int temp = g.edgeList[i];
    h_data[i] = temp;
    temp = g.srcList[i];
    h_src[i] = temp;
    temp = edgeLen[i];
    h_weight[i] = temp;
  }


  int* d_meta;
  int* d_data;
  int* d_src;
  int* d_weight;
  int* d_rev_meta;
  bool* d_modified_next;

  cudaMalloc(&d_meta, sizeof(int)*(1+V));
  cudaMalloc(&d_data, sizeof(int)*(E));
  cudaMalloc(&d_src, sizeof(int)*(E));
  cudaMalloc(&d_weight, sizeof(int)*(E));
  cudaMalloc(&d_rev_meta, sizeof(int)*(V+1));
  cudaMalloc(&d_modified_next, sizeof(bool)*(V));

  cudaMemcpy(  d_meta,   h_meta, sizeof(int)*(V+1), cudaMemcpyHostToDevice);
  cudaMemcpy(  d_data,   h_data, sizeof(int)*(E), cudaMemcpyHostToDevice);
  cudaMemcpy(   d_src,    h_src, sizeof(int)*(E), cudaMemcpyHostToDevice);
  cudaMemcpy(d_weight, h_weight, sizeof(int)*(E), cudaMemcpyHostToDevice);
  cudaMemcpy(d_rev_meta, h_rev_meta, sizeof(int)*((V+1)), cudaMemcpyHostToDevice);

  // CSR END
  //LAUNCH CONFIG
  const unsigned threadsPerBlock = 512;
  unsigned numThreads   = (V < threadsPerBlock)? 512: V;
  unsigned numBlocks    = (V+threadsPerBlock-1)/threadsPerBlock;


  // TIMER START
  cudaEvent_t start, stop;
  cudaEventCreate(&start);
  cudaEventCreate(&stop);
  float milliseconds = 0;
  cudaEventRecord(start,0);


  //DECLAR DEVICE AND HOST vars in params

  //BEGIN DSL PARSING 
  int kcore_count = 0; // asst in .cu

  int update_count = 1; // asst in .cu

  int* d_indeg;
  cudaMalloc(&d_indeg, sizeof(int)*(V));

  int* d_indeg_prev;
  cudaMalloc(&d_indeg_prev, sizeof(int)*(V));

  k_core_kernel<<<numBlocks, threadsPerBlock>>>(V,E,d_meta,d_data,d_src,d_weight,d_rev_meta,d_modified_next,d_indeg,d_indeg_prev);
  cudaDeviceSynchronize();



  cudaMemcpyToSymbol(::k, &k, sizeof(int), 0, cudaMemcpyHostToDevice);
  k_core_kernel<<<numBlocks, threadsPerBlock>>>(V,E,d_meta,d_data,d_src,d_weight,d_rev_meta,d_modified_next,d_indeg_prev,d_indeg);
  cudaDeviceSynchronize();
  cudaMemcpyFromSymbol(&k, ::k, sizeof(int), 0, cudaMemcpyDeviceToHost);



  ;
  cudaMemcpyToSymbol(::k, &k, sizeof(int), 0, cudaMemcpyHostToDevice);
  k_core_kernel<<<numBlocks, threadsPerBlock>>>(V,E,d_meta,d_data,d_src,d_weight,d_rev_meta,d_modified_next,d_indeg_prev,d_indeg);
  cudaDeviceSynchronize();
  cudaMemcpyFromSymbol(&k, ::k, sizeof(int), 0, cudaMemcpyDeviceToHost);



  do{
    update_count = 0;
    cudaMemcpyToSymbol(::k, &k, sizeof(int), 0, cudaMemcpyHostToDevice);
    k_core_kernel<<<numBlocks, threadsPerBlock>>>(V,E,d_meta,d_data,d_src,d_weight,d_rev_meta,d_modified_next,d_indeg);
    cudaDeviceSynchronize();
    cudaMemcpyFromSymbol(&k, ::k, sizeof(int), 0, cudaMemcpyDeviceToHost);



    ;
    ;

  }while(update_count > 0);
  cudaMemcpyToSymbol(::k, &k, sizeof(int), 0, cudaMemcpyHostToDevice);
  k_core_kernel<<<numBlocks, threadsPerBlock>>>(V,E,d_meta,d_data,d_src,d_weight,d_rev_meta,d_modified_next,d_indeg);
  cudaDeviceSynchronize();
  cudaMemcpyFromSymbol(&k, ::k, sizeof(int), 0, cudaMemcpyDeviceToHost);



  ;

  //cudaFree up!! all propVars in this BLOCK!
  cudaFree(d_indeg_prev);
  cudaFree(d_indeg);

  //TIMER STOP
  cudaEventRecord(stop,0);
  cudaEventSynchronize(stop);
  cudaEventElapsedTime(&milliseconds, start, stop);
  printf("GPU Time: %.6f ms\n", milliseconds);

} //end FUN
