/* $Id: uniform_args.h,v 1.1 2010-12-10 07:42:37 locle Exp $ */
#ifndef Already_Included_Uniform_Args
#define Already_Included_Uniform_Args

#include <basic/String.h>
 
namespace omega {

typedef struct
    {
    bool gen_do_closure;
    bool non_data_ok;
    bool manual;
    bool simple;
    bool trace_uniform;
    int Num_Procs;
    int n;
    double comps_per_comm;
    } uniform_args_struct;
 
extern uniform_args_struct uniform_args;

extern void process_uniform_args(char *arg);
 
}

#endif


