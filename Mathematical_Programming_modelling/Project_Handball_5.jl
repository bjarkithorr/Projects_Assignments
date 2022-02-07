# Import packages
using JuMP
using Gurobi
using Cbc
using Printf
##################
include("handball_data-22.jl")

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


###########################################################################################################################################################
############################################################## MODEL FROM 4a ##############################################################################
###########################################################################################################################################################

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



distance_H4a = value(sum(x[m,r] * match_arena[m,a] * referee_arena_distances[r,a] for m=1:M,r=1:R,a=1:A))



###############################################################################################################################################
############################################## model from 4 B #################################################################################
###############################################################################################################################################

# model
pairs = Model(Gurobi.Optimizer)

# Variable
@variable(pairs, x[m=1:M,r=1:R],Bin)

# maximize referee pair
@objective(pairs, Max, sum(x[m,r1]*ref_pair[r1,r2]*x[m,r2]*0.5 for m=1:M,r1=1:R,r2=1:R))

# only two referee per game
@constraint(pairs, [m=1:M], sum( x[m,r] for r=1:R) == 2)

# Only 1 game per day per referee
@constraint(pairs, [d=1:D, r=1:R], sum( x[m,r] * match_time[m,d] for m=1:M) <= 1)

# Dates when X referee is not available 
@constraint(pairs, [d=1:D, r=1:R, m=1:M], 1 - ref_not_available[r,d] >= match_time[m,d] * x[m,r])

optimize!(pairs)

min_pairs = objective_value(pairs)

####################################################################################################################
##############    SECOND PART: SOLVING THE MIN DISTANCE PROBLEM WITH REFEREE PAIR CONSTRAINT #######################
####################################################################################################################


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

#min number of referee paired games
@constraint(dist, sum(x[m,r1]*ref_pair[r1,r2]*x[m,r2]*0.5 for m=1:M,r1=1:R,r2=1:R) >= min_pairs)

println("Solving Model")
optimize!(dist)
#************************************************************************


dist_constr = objective_value(dist)
pairs_H4b = value(sum(x[m,r1]*ref_pair[r1,r2]*x[m,r2]*0.5 for m=1:M,r1=1:R,r2=1:R))



#######################################################################################################################################################################################
####################################  NOW WE HAVE DISTANCE AND PAIRS FROM 4 AND WILL MODEL PROBLEM 5 ##################################################################################
#######################################################################################################################################################################################

# STORED VARIABLES FROM PROBLEM 4 MODELS A & B:
#matches_H4b
#distance_H4a

"Minimize the total number of times the teams are refereed by the same referee
more than 3 times and the number of times the same referee is used twice in row
for the same team. As an example, if a referee officiates the same team five times
during the season, a ”cost” of 2 would be incurred in the first component of the
objective.

Regarding the two objective functions from H4, add constraints that ensure that
the distance travelled is at most 35% worse than the best solution to H4a and at
least 70% of the number of matches given in the solution to H4b are refereed by
referee pairs.
"
# 1 penalty for each game in excess of 3 that referee judges the same team so 6 games with same team is 3 penalties
# 1 penalty each time referee does same team twice in a row, so 2 consecutive games three times is 3 points

#parameter adds
T = 31 #31 teams

#subsets of match numbers for each team to see which games are consecutive per team
consec_games = []

for t = 1:T
    tmp = []
    for m = 1:M
        if team_match[t,m] == true
            append!(tmp, m)
        end
    end
    push!(consec_games, tmp)
end




# model
games = Model(Gurobi.Optimizer)

# Variables
@variable(games, x[m=1:M,r=1:R],Bin)                    #does referee r judge game m [y/n]
@variable(games, y[t=1:T,r=1:R] >= 0)                   #how many games in excess of three for team-referee pair occurs
@variable(games, z[r=1:R,t=1:T,m=1:M] >= 0)

# minimize total "penalty" points for referee per team
@objective(games, Min, sum(y[t,r] for t=1:T, r=1:R) + sum(z[r,t,m] for r=1:R, t=1:T,m=1:M))

# only two referee per game
@constraint(games, [m=1:M], sum( x[m,r] for r=1:R) == 2)

# Only 1 game per day per referee
@constraint(games, [d=1:D, r=1:R], sum( x[m,r] * match_time[m,d] for m=1:M) <= 1)

# Dates when X referee is not available 
@constraint(games, [d=1:D, r=1:R, m=1:M], 1 - ref_not_available[r,d] >= match_time[m,d] * x[m,r])

#min number of referee paired games
@constraint(games, sum(x[m,r1]*ref_pair[r1,r2]*x[m,r2]*0.5 for m=1:M,r1=1:R,r2=1:R) >= pairs_H4b * 0.7)

# maximum allowed total distance
@constraint(games, sum(x[m,r] * match_arena[m,a] * referee_arena_distances[r,a] for m=1:M,r=1:R,a=1:A) <= distance_H4a * 1.35)

# count times games excess 3 for referee-team pair
@constraint(games,[r=1:R, t=1:T], sum(x[m,r]*team_match[t,m] for m=1:M) <= y[t,r] + 3)

# count times referee has consecutive games with a team
@constraint(games,[r=1:R,t=1:T,T_set=1:T,m=2:length(T_set)],x[r,T_set[m]] + x[r,T_set[m-1]] <= (1+ z[r,t,T_set[m]]))


println("Solving Model")
optimize!(games)

objective_value(games)
#************************************************************************

# Report results
println("-------------------------------------");
if termination_status(games) == MOI.OPTIMAL
    println("RESULTS:")
    println("objective = $(objective_value(games))\n")
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


