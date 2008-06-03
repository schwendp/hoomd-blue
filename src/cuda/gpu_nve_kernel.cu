/*
Highly Optimized Object-Oriented Molecular Dynamics (HOOMD) Open
Source Software License
Copyright (c) 2008 Ames Laboratory Iowa State University
All rights reserved.

Redistribution and use of HOOMD, in source and binary forms, with or
without modification, are permitted, provided that the following
conditions are met:

* Redistributions of source code must retain the above copyright notice,
this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.

* Neither the name of the copyright holder nor the names HOOMD's
contributors may be used to endorse or promote products derived from this
software without specific prior written permission.

Disclaimer

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDER AND
CONTRIBUTORS ``AS IS''  AND ANY EXPRESS OR IMPLIED WARRANTIES,
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. 

IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS  BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
THE POSSIBILITY OF SUCH DAMAGE.
*/

// $Id$
// $URL$

#include "gpu_pdata.h"
#include "gpu_updaters.h"
#include "gpu_integrator.h"

#ifdef WIN32
#include <cassert>
#else
#include <assert.h>
#endif

#include <stdio.h>

/*! \file gpu_nve_kernel.cu
	\brief Contains kernel code for the NVE integrator on the GPU
*/

//! The texture for reading the pdata pos array
texture<float4, 1, cudaReadModeElementType> pdata_pos_tex;
texture<float4, 1, cudaReadModeElementType> pdata_vel_tex;
texture<float4, 1, cudaReadModeElementType> pdata_accel_tex;

extern "C" __global__ void nve_pre_step_kernel(gpu_pdata_arrays pdata, float deltaT, gpu_boxsize box)
	{
	int pidx = blockIdx.x * blockDim.x + threadIdx.x;
	// do velocity verlet update
	// r(t+deltaT) = r(t) + v(t)*deltaT + (1/2)a(t)*deltaT^2
	// v(t+deltaT/2) = v(t) + (1/2)a*deltaT
	
	if (pidx < pdata.N)
		{	
		float4 pos = tex1Dfetch(pdata_pos_tex, pidx);
		
		float px = pos.x;
		float py = pos.y;
		float pz = pos.z;
		float pw = pos.w;
		
		float4 vel = tex1Dfetch(pdata_vel_tex, pidx);
		float4 accel = tex1Dfetch(pdata_accel_tex, pidx);
		
		px += vel.x * deltaT + (1.0f/2.0f) * accel.x * deltaT * deltaT;
		vel.x += (1.0f/2.0f) * accel.x * deltaT;
		
		py += vel.y * deltaT + (1.0f/2.0f) * accel.y * deltaT * deltaT;
		vel.y += (1.0f/2.0f) * accel.y * deltaT;
		
		pz += vel.z * deltaT + (1.0f/2.0f) * accel.z * deltaT * deltaT;
		vel.z += (1.0f/2.0f) * accel.z * deltaT;
		
		// time to fix the periodic boundary conditions
		px -= box.Lx * rintf(px * box.Lxinv);
		py -= box.Ly * rintf(py * box.Lyinv);
		pz -= box.Lz * rintf(pz * box.Lzinv);
	
		float4 pos2;
		pos2.x = px;
		pos2.y = py;
		pos2.z = pz;
		pos2.w = pw;
						
		// write out the results
		pdata.pos[pidx] = pos2;
		pdata.vel[pidx] = vel;
		}	
	}

cudaError_t nve_pre_step(gpu_pdata_arrays *pdata, gpu_boxsize *box, float deltaT)
	{
    assert(pdata);

    // setup the grid to run the kernel
    int M = 256;
    dim3 grid( (pdata->N/M) + 1, 1, 1);
    dim3 threads(M, 1, 1);

	// bind the textures
	cudaError_t error = cudaBindTexture(0, pdata_pos_tex, pdata->pos, sizeof(float4) * pdata->N);
	if (error != cudaSuccess)
		return error;

	error = cudaBindTexture(0, pdata_vel_tex, pdata->vel, sizeof(float4) * pdata->N);
	if (error != cudaSuccess)
		return error;

	error = cudaBindTexture(0, pdata_accel_tex, pdata->accel, sizeof(float4) * pdata->N);
	if (error != cudaSuccess)
		return error;

    // run the kernel
    nve_pre_step_kernel<<< grid, threads >>>(*pdata, deltaT, *box);
	
	#ifdef NDEBUG
	return cudaSuccess;
	#else
	cudaThreadSynchronize();
	return cudaGetLastError();
	#endif
	}


extern "C" __global__ void nve_step_kernel(gpu_pdata_arrays pdata, float4 **force_data_ptrs, int num_forces, float deltaT)
	{
	int pidx = blockIdx.x * blockDim.x + threadIdx.x;
	// v(t+deltaT) = v(t+deltaT/2) + 1/2 * a(t+deltaT)*deltaT

	float4 accel = integrator_sum_forces_inline(pidx, pdata.N, force_data_ptrs, num_forces);
	if (pidx < pdata.N)
		{
		float4 vel = tex1Dfetch(pdata_vel_tex, pidx);
			
		vel.x += (1.0f/2.0f) * accel.x * deltaT;
		vel.y += (1.0f/2.0f) * accel.y * deltaT;
		vel.z += (1.0f/2.0f) * accel.z * deltaT;
		
		// write out data
		pdata.vel[pidx] = vel;
		// since we calculate the acceleration, we need to write it for the next step
		pdata.accel[pidx] = accel;
		}
	}
	
cudaError_t nve_step(gpu_pdata_arrays *pdata, float4 **force_data_ptrs, int num_forces, float deltaT)
	{
    assert(pdata);

    // setup the grid to run the kernel
    int M = 192;
    dim3 grid( (pdata->N/M) + 1, 1, 1);
    dim3 threads(M, 1, 1);

	// bind the texture
	cudaError_t error = cudaBindTexture(0, pdata_vel_tex, pdata->vel, sizeof(float4) * pdata->N);
	if (error != cudaSuccess)
		return error;

    // run the kernel
    nve_step_kernel<<< grid, threads >>>(*pdata, force_data_ptrs, num_forces, deltaT);

	#ifdef NDEBUG
	return cudaSuccess;
	#else
	cudaThreadSynchronize();
	return cudaGetLastError();
	#endif
	}
