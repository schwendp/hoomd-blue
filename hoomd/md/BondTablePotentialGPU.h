// Copyright (c) 2009-2016 The Regents of the University of Michigan
// This file is part of the HOOMD-blue project, released under the BSD 3-Clause License.


// Maintainer: joaander

#include "BondTablePotential.h"
#include "BondTablePotentialGPU.cuh"
#include "hoomd/Autotuner.h"

/*! \file BondTablePotentialGPU.h
    \brief Declares the BondTablePotentialGPU class
*/

#ifdef NVCC
#error This header cannot be compiled by nvcc
#endif

#ifndef __BONDTABLEPOTENTIALGPU_H__
#define __BONDTABLEPOTENTIALGPU_H__

//! Compute table based bond potentials on the GPU
/*! Calculates exactly the same thing as BondTablePotential, but on the GPU

    The GPU kernel for calculating this can be found in BondTablePotentialGPU.cu/
    \ingroup computes
*/
class BondTablePotentialGPU : public BondTablePotential
    {
    public:
        //! Constructs the compute
        BondTablePotentialGPU(boost::shared_ptr<SystemDefinition> sysdef,
                          unsigned int table_width,
                          const std::string& log_suffix="");

        //! Destructor
        virtual ~BondTablePotentialGPU();

        //! Set autotuner parameters
        /*! \param enable Enable/disable autotuning
            \param period period (approximate) in time steps when returning occurs
        */
        virtual void setAutotunerParams(bool enable, unsigned int period)
            {
            BondTablePotential::setAutotunerParams(enable, period);
            m_tuner->setPeriod(period);
            m_tuner->setEnabled(enable);
            }

    private:
        boost::scoped_ptr<Autotuner> m_tuner; //!< Autotuner for block size
        GPUArray<unsigned int> m_flags;       //!< Flags set during the kernel execution

        //! Actually compute the forces
        virtual void computeForces(unsigned int timestep);
    };

//! Exports the BondTablePotentialGPU class to python
void export_BondTablePotentialGPU();

#endif