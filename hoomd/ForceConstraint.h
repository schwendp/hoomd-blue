// Copyright (c) 2009-2016 The Regents of the University of Michigan
// This file is part of the HOOMD-blue project, released under the BSD 3-Clause License.


// Maintainer: joaander

#include "ForceCompute.h"

#include <boost/shared_ptr.hpp>

/*! \file ForceConstraint.h
    \brief Declares a base class for computing constraint
*/

#ifdef NVCC
#error This header cannot be compiled by nvcc
#endif

#ifndef __ForceConstraint_H__
#define __ForceConstraint_H__

//! Base class for all constraint forces
/*! See Integrator for detailed documentation on constraint force implementation.
    \ingroup computes
*/
class ForceConstraint : public ForceCompute
    {
    public:
        //! Constructs the compute
        ForceConstraint(boost::shared_ptr<SystemDefinition> sysdef);

        //! Return the number of DOF removed by this constraint
        /*! The base class ForceConstraint returns 0, derived classes should override
        */
        virtual unsigned int getNDOFRemoved()
            {
            return 0;
            }

    protected:

        //! Compute the forces
        virtual void computeForces(unsigned int timestep);
    };

//! Exports the ForceConstraint to python
void export_ForceConstraint();

#endif