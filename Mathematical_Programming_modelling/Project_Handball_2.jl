# Import packages
using JuMP
using Gurobi
using Cbc
using Printf
##################
include("handball_data-22.jl")

#After inspecting your solution to H1, you note that there is quite some variation in the number of matches each referee officiates. 
#You have been asked to see if it is possible to come up with a referee schedule in which the referee with the most matches 
#officiates at most 5 more matches than the referee with the least matches.
#Adjust your formulation so that adheres to this request. 

#What is the total distance of the schedule (if such a schedule exists!)

#Answer H2: An optimal referee schedule that minimizes the distance
#travelled, the modified MIP model, and the Julia program used to obtain
#this result.


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
@variable(dist, cMax >= 0) # stores the max over coverage
@variable(dist, cMin >= 0)  #stores the min over coverage

# minimize total distance travelled by the referee
@objective(dist, Min, sum(x[m,r] * match_arena[m,a] * referee_arena_distances[r,a] for m=1:M,r=1:R,a=1:A))

# only two referee per game
@constraint(dist, [m=1:M], sum( x[m,r] for r=1:R) == 2)

# Only 1 game per day per referee
@constraint(dist, [d=1:D, r=1:R], sum( x[m,r] * match_time[m,d] for m=1:M) <= 1)

# Dates when X referee is not available 
@constraint(dist, [d=1:D, r=1:R, m=1:M], 1 - ref_not_available[r,d] >= match_time[m,d] * x[m,r])

# max referee only allowed to take 5 more games than the min referee 
@constraint(dist,[r1=1:R,r2=1:R], sum(x[m,r1] for m=1:M) - 5 <= sum(x[m,r2] for m=1:M))



println("Solving Model")
optimize!(dist)
#************************************************************************
#************************************************************************
# Report results
println("-------------------------------------");
if termination_status(dist) == MOI.OPTIMAL
    println("RESULTS:")
    println("objective = $(objective_value(dist))\n")
else
    println(" No solution")
end
println("--------------------------------------");


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

