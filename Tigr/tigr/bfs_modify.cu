
#include "../shared/timer.hpp"
#include "../shared/tigr_utilities.hpp"
#include "../shared/graph.hpp"
#include "../shared/virtual_graph.hpp"
#include "../shared/globals.hpp"
#include "../shared/argument_parsing.hpp"
#include "../shared/gpu_error_check.cuh"




__global__ void kernel(unsigned int numParts, 
							unsigned int *nodePointer, 
							PartPointer *partNodePointer,
							unsigned int *edgeList, 
							unsigned int *dist, 
							bool *finished,
							int level)
{
	unsigned int partId = blockDim.x * blockIdx.x + threadIdx.x;

	if(partId < numParts)
	{
		unsigned int id = partNodePointer[partId].node;
		unsigned int part = partNodePointer[partId].part;

		if(dist[id] != level)
			return;

		unsigned int thisPointer = nodePointer[id];
		unsigned int degree = edgeList[thisPointer];
			
		unsigned int numParts;
		if(degree % Part_Size == 0)
			numParts = degree / Part_Size ;
		else
			numParts = degree / Part_Size + 1;

		
		unsigned int end;

		unsigned int ofs = thisPointer + part + 1;

		for(int i=0; i<Part_Size; i++)
		{
			if(part + i*numParts >= degree)
				break;
			end = ofs + i*numParts;
			
			if(dist[edgeList[end]] == DIST_INFINITY)
			{
				dist[edgeList[end]] = level + 1;
				*finished = false;
			}
		}
		
	}
}


__global__ void clearLabel(bool *label, unsigned int size)
{
	unsigned int id = blockDim.x * blockIdx.x + threadIdx.x;
	if(id < size)
		label[id] = false;
}

__global__ void unifyMaxValues(unsigned int* d_dist_s, unsigned int* d_dist_d, int size) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < size) {
        d_dist_s[idx] = max(d_dist_s[idx], d_dist_d[idx]);
        d_dist_d[idx] = d_dist_s[idx]; // This line ensures both arrays have the same value.
    }
}
int main(int argc, char** argv)
{	
	ArgumentParser arguments(argc, argv, true, false);
	
	Graph graph_d("/root/Tigr/datasets/LiveJournal/dense.txt", false);
	Graph graph_s("/root/Tigr/datasets/LiveJournal/sparse.txt", false);
	
	graph_d.ReadGraph();
    graph_s.ReadGraph();
	
	VirtualGraph vGraph_d(graph_d);
	VirtualGraph vGraph_s(graph_s);
	vGraph_d.MakeUGraph();
	vGraph_s.MakeUGraph();
	
	uint num_nodes_d = graph_d.num_nodes;
	uint num_edges_d = graph_d.num_edges;

	uint num_nodes_s = graph_s.num_nodes;
	uint num_edges_s = graph_s.num_edges;
	
	if(arguments.hasDeviceID)
		cudaSetDevice(arguments.deviceID);

	cudaFree(0);
	
	unsigned int *dist_d;
	dist_d  = new unsigned int[num_nodes_d];

	for(int i=0; i<num_nodes_d; i++)
	{
		dist_d[i] = DIST_INFINITY;
	}
	dist_d[arguments.sourceNode] = 0;

	unsigned int *dist_s;
	dist_s  = new unsigned int[num_nodes_s];

	for(int i=0; i<num_nodes_s; i++)
	{
		dist_s[i] = DIST_INFINITY;
	}
	dist_s[arguments.sourceNode] = 0;
	

	unsigned int *d_nodePointer_d, *d_edgeList_d, *d_dist_d;
    PartPointer *d_partNodePointer_d; 
    bool *d_finished_d;
    // graph_d에 대한 메모리 할당
    gpuErrorcheck(cudaMalloc(&d_nodePointer_d, num_nodes_d * sizeof(unsigned int)));
    gpuErrorcheck(cudaMalloc(&d_edgeList_d, (num_edges_d + num_nodes_d) * sizeof(unsigned int)));
    gpuErrorcheck(cudaMalloc(&d_dist_d, num_nodes_d * sizeof(unsigned int)));
    gpuErrorcheck(cudaMalloc(&d_finished_d, sizeof(bool)));
    gpuErrorcheck(cudaMalloc(&d_partNodePointer_d, vGraph_d.numParts * sizeof(PartPointer)));

	gpuErrorcheck(cudaMemcpy(d_nodePointer_d, vGraph_d.nodePointer, num_nodes_d * sizeof(unsigned int), cudaMemcpyHostToDevice));
	gpuErrorcheck(cudaMemcpy(d_edgeList_d, vGraph_d.edgeList, (num_edges_d + num_nodes_d) * sizeof(unsigned int), cudaMemcpyHostToDevice));
	gpuErrorcheck(cudaMemcpy(d_dist_d, dist_d, num_nodes_d * sizeof(unsigned int), cudaMemcpyHostToDevice));
	gpuErrorcheck(cudaMemcpy(d_partNodePointer_d, vGraph_d.partNodePointer, vGraph_d.numParts * sizeof(PartPointer), cudaMemcpyHostToDevice));
	
	unsigned int *d_nodePointer_s, *d_edgeList_s, *d_dist_s;
    PartPointer *d_partNodePointer_s; 
    bool *d_finished_s;
    // graph_s에 대한 메모리 할당
    gpuErrorcheck(cudaMalloc(&d_nodePointer_s, num_nodes_s * sizeof(unsigned int)));
    gpuErrorcheck(cudaMalloc(&d_edgeList_s, (num_edges_s + num_nodes_s) * sizeof(unsigned int)));
    gpuErrorcheck(cudaMalloc(&d_dist_s, num_nodes_s * sizeof(unsigned int)));
    gpuErrorcheck(cudaMalloc(&d_finished_s, sizeof(bool)));
    gpuErrorcheck(cudaMalloc(&d_partNodePointer_s, vGraph_s.numParts * sizeof(PartPointer)));
	
	gpuErrorcheck(cudaMemcpy(d_nodePointer_s, vGraph_s.nodePointer, num_nodes_s * sizeof(unsigned int), cudaMemcpyHostToDevice));
	gpuErrorcheck(cudaMemcpy(d_edgeList_s, vGraph_s.edgeList, (num_edges_s + num_nodes_s) * sizeof(unsigned int), cudaMemcpyHostToDevice));
	gpuErrorcheck(cudaMemcpy(d_dist_s, dist_s, num_nodes_s * sizeof(unsigned int), cudaMemcpyHostToDevice));
	gpuErrorcheck(cudaMemcpy(d_partNodePointer_s, vGraph_s.partNodePointer, vGraph_s.numParts * sizeof(PartPointer), cudaMemcpyHostToDevice));
	
	cudaStream_t stream1, stream2;
	cudaStreamCreate(&stream1);
	cudaStreamCreate(&stream2);
	bool finished_d;
	bool finished_s;

	Timer t;
	t.Start();

	int itr = 0;
	int level = 0;
	do
	{
		itr++;
		finished_d=true;
		finished_s = true;
		gpuErrorcheck(cudaMemcpy(d_finished_d, &finished_d, sizeof(bool), cudaMemcpyHostToDevice));
		gpuErrorcheck(cudaMemcpy(d_finished_s, &finished_s, sizeof(bool), cudaMemcpyHostToDevice));
		if(itr % 2 == 1)
		{
			kernel<<< vGraph_d.numParts/512 + 1 , 512,0, stream1  >>>(vGraph_d.numParts, 
														d_nodePointer_d,
														d_partNodePointer_d,
														d_edgeList_d, 
														d_dist_d, 
														d_finished_d,
														level);
			kernel<<< vGraph_s.numParts/512 + 1 , 512,0, stream2 >>>(vGraph_s.numParts, 
														d_nodePointer_s,
														d_partNodePointer_s,
														d_edgeList_s, 
														d_dist_s, 
														d_finished_s,
														level);
			// Assuming 'size' is the size of your d_dist_s and d_dist_d arrays
			int threadsPerBlock = 512;
			int blocksPerGrid = (num_nodes_d + threadsPerBlock - 1) / threadsPerBlock;
			unifyMaxValues<<<blocksPerGrid, threadsPerBlock,0, stream2>>>(d_dist_s, d_dist_d, num_nodes_d);

		}
		else
		{
			kernel<<< vGraph_d.numParts/512 + 1 , 512,0, stream1>>>(vGraph_d.numParts, 
														d_nodePointer_d, 
														d_partNodePointer_d,
														d_edgeList_d, 
														d_dist_d, 
														d_finished_d,
														level);													
			kernel<<< vGraph_s.numParts/512 + 1 , 512 ,0, stream2>>>(vGraph_s.numParts, 
														d_nodePointer_s, 
														d_partNodePointer_s,
														d_edgeList_s, 
														d_dist_s, 
														d_finished_s,
														level);		
			int threadsPerBlock = 512;
			int blocksPerGrid = (num_nodes_d + threadsPerBlock - 1) / threadsPerBlock;
			unifyMaxValues<<<blocksPerGrid, threadsPerBlock,0, stream2>>>(d_dist_s, d_dist_d, num_nodes_d);
		}
	
		gpuErrorcheck( cudaPeekAtLastError() );
		gpuErrorcheck( cudaDeviceSynchronize() );
		
		gpuErrorcheck(cudaMemcpy(&finished_d, d_finished_d, sizeof(bool), cudaMemcpyDeviceToHost));
		gpuErrorcheck(cudaMemcpy(&finished_s, d_finished_s, sizeof(bool), cudaMemcpyDeviceToHost));
		level++;

	} while (!(finished_d));
	
	cout << "Number of iterations = " << itr << endl;

	float runtime = t.Finish();
	cout << "Processing finished in " << runtime << " (ms).\n";
		
	
	gpuErrorcheck(cudaMemcpy(dist_d, d_dist_d, num_nodes_d*sizeof(unsigned int), cudaMemcpyDeviceToHost));
	gpuErrorcheck(cudaMemcpy(dist_s, d_dist_s, num_nodes_s*sizeof(unsigned int), cudaMemcpyDeviceToHost));
	utilities::PrintResults(dist_d, 30);
	utilities::PrintResults(dist_s, 30);
	if(arguments.hasOutput)
		utilities::SaveResults(arguments.output, dist_d, num_nodes_d);
		utilities::SaveResults(arguments.output, dist_s, num_nodes_s);
	

	gpuErrorcheck(cudaFree(d_nodePointer_d));
    gpuErrorcheck(cudaFree(d_edgeList_d));
    gpuErrorcheck(cudaFree(d_dist_d));
    gpuErrorcheck(cudaFree(d_finished_d));
    gpuErrorcheck(cudaFree(d_partNodePointer_d));

    gpuErrorcheck(cudaFree(d_nodePointer_s));
    gpuErrorcheck(cudaFree(d_edgeList_s));
    gpuErrorcheck(cudaFree(d_dist_s));
    gpuErrorcheck(cudaFree(d_finished_s));
    gpuErrorcheck(cudaFree(d_partNodePointer_s));

    delete[] dist_d;
    delete[] dist_s;
	return 0;

}
