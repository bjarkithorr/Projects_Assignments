# Import packages
using JuMP
using Gurobi
using Cbc
using Printf
##################
include("Final Project\\handball_data-22.jl")

# CONSTRAINTS
#- Every team play each team twice (home and away)
#- Two referees must be assigned to each match.
#- A referee can only officiate one match a day.
#- The referees have jobs and can hence not officiate on all days. 

#Assignment H1
# find a referee schedule that minimizes the total distance travelled by the referees. 

#referee_arena_distances=zeros(Float64,52 ,70 )

#match_arena=falses(198,70 )
M = 198
A = 70
R = 52
D = 51
#match_time=falses(198,51 )
#ref_pair=falses(52 ,52 )
#ref_not_available=falses(52 ,51 )
#team_match=falses(31 ,198)



# model
dist = Model(Gurobi.Optimizer)

# Variable
@variable(dist, x[m=1:M,r=1:R],Bin)

# minimize total distance travelled by the referee
@objective(dist, Min, sum(x[m,r] * match_arena[m,a] * referee_arena_distances[r,a] for m=1:M,r=1:R,a=1:A))

# only two referee per game
@constraint(dist, [m=1:M], sum( x[m,r] for r=1:R) == 2)

# Only 1 game per day per referee
@constraint(dist, [d=1:D, r=1:R], sum( x[m,r] * match_time[m,d] for m=1:M) <= 1)

# Dates when X referee is not available 
@constraint(dist, [d=1:D, r=1:R, m=1:M], 1 - ref_not_available[r,d] >= match_time[m,d] * x[m,r])



println("Solving Model")
optimize!(dist)
#************************************************************************
#************************************************************************
# Report results
println("-------------------------------------");
if termination_status(dist) == MOI.OPTIMAL
    println("RESULTS:")
    println("objective = $(objective_value(dist))\n")
    for m = 1:M
        for r=1:R
            if value(x[m,r]) == 1
                println("Match $(m) referee nr. $(r)")
            end
        end
    end      
else
    println(" No solution")
end
println("--------------------------------------");

dist_constr = objective_value(dist)




####################################################################################################################
##############    SECOND PART: SOLVING THE MAX REFEREE PAIRING PROBLEM WITH TIME CONSTRAINT ########################
####################################################################################################################


# model
pairs = Model(Gurobi.Optimizer)

# Variable
@variable(pairs, x[m=1:M,r=1:R],Bin)

# minimize total distance travelled by the referee
@objective(pairs, Max, sum(x[m,r1]*ref_pair[r1,r2]*x[m,r2]*0.5 for m=1:M,r1=1:R,r2=1:R))

# only two referee per game
@constraint(pairs, [m=1:M], sum( x[m,r] for r=1:R) == 2)

# Only 1 game per day per referee
@constraint(pairs, [d=1:D, r=1:R], sum( x[m,r] * match_time[m,d] for m=1:M) <= 1)

# Dates when X referee is not available 
@constraint(pairs, [d=1:D, r=1:R, m=1:M], 1 - ref_not_available[r,d] >= match_time[m,d] * x[m,r])

# Max time constraint
@constraint(pairs, sum(x[m,r] * match_arena[m,a] * referee_arena_distances[r,a] for m=1:M,r=1:R,a=1:A) <= dist_constr)



println("Solving Model")
optimize!(pairs)

# Report results
println("-------------------------------------");
if termination_status(pairs) == MOI.OPTIMAL
    println("RESULTS:")
    println("objective = $(objective_value(pairs))\n")
else
    println(" No solution")
end
println("--------------------------------------");


distance_H4a = sum(x[m,r] * match_arena[m,a] * referee_arena_distances[r,a] for m=1:M,r=1:R,a=1:A)

