// Copyright (c) 2009-2016 The Regents of the University of Michigan
// This file is part of the HOOMD-blue project, released under the BSD 3-Clause License.


// Maintainer: joaander

/*! \file TwoStepBDGPU.cuh
    \brief Declares GPU kernel code for Brownian dynamics on the GPU. Used by TwoStepBDGPU.
*/

#include "hoomd/ParticleData.cuh"
#include "TwoStepLangevinGPU.cuh"
#include "hoomd/HOOMDMath.h"

#ifndef __TWO_STEP_BD_GPU_CUH__
#define __TWO_STEP_BD_GPU_CUH__

//! Kernel driver for the first part of the Brownian update called by TwoStepBDGPU
cudaError_t gpu_brownian_step_one(Scalar4 *d_pos,
                                  Scalar4 *d_vel,
                                  int3 *d_image,
                                  const BoxDim &box,
                                  const Scalar *d_diameter,
                                  const unsigned int *d_tag,
                                  const unsigned int *d_group_members,
                                  const unsigned int group_size,
                                  const Scalar4 *d_net_force,
                                  const Scalar *d_gamma_r,
                                  Scalar4 *d_orientation,
                                  Scalar4 *d_torque,
                                  const Scalar3 *d_inertia,
                                  Scalar4 *d_angmom,
                                  const langevin_step_two_args& langevin_args,
                                  const bool aniso,
                                  const Scalar deltaT,
                                  const unsigned int D,
                                  const bool d_noiseless_t,
                                  const bool d_noiseless_r);

#endif //__TWO_STEP_BD_GPU_CUH__