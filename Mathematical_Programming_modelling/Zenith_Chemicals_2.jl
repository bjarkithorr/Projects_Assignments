# Import packages
using JuMP
using Gurobi
using Cbc
using Printf
##################

TSP_per_month = 183000
HCMD_per_month = 212000

blending_machines = 36
grading_machines = 20

# Run 8 hours per day all of the month
# Execpt the first day of the month for cleaning
# A machine can only procude one type of product each month

# Table 1 - usage of raw material 
use_raw_mat_columns = ("TSP", "HCMD")
use_raw_mat_rows = ("Alpha", "Beta",  "Delta")
use_raw_mat = [15 31.5 ; 27 18 ; 22 23.5]

#Storage cost
stor_cost_columns = ("Alpha", "Beta", "Delta")
stor_cost = [0.7 1.25 1.85]

# 100 of each product is stored 1-may, and at least 100 of each should be stored in end of august
max_storage_total = 2500

#Table 2 - production time
prod_time_columns = ("blending", "grading")
prod_time_rows = ("Alpha" , "Beta" , "Delta")
prod_time = [1.25 1; 2.5 3.5; 1.75 0.75]

#Table 3 - Production cost for finished products ($ per DCM)
prod_cost_columns = ("May", "June","July", "August")
prod_cost_rows = ("Alpha", "Beta", "Delta")
prod_cost =[10 11 12 13; 17 17 19.5 19.5; 15.5 18 18 15.5]

#Product pricing May - June
# months as columns
prod_price_rows = ("Alpha", "Beta", "Delta")
prod_price = [28 28 41 41; 
            52.5 52.5 57.75 57.75;
            42.75 42.75 47 47]


### Demand Tables ###
months = ("May", "June","July", "August") # as columns
regions = ("Region A", "Region B", "Region C", "Region D") # as rows

demand_alpha = [500 600 700 400;
                800 950 1000 750;
                250 300 250 200;
                500 600 500 400]

total_demand_months_alpha= [2050 2450 2450 1750]

demand_beta = [250 250 200 200;
                400 400 400 400;
                150 125 100 75;
                275 250 225 225]

total_demand_months_beta = [1075 1025 925 900]

demand_delta = [1000 1200 1500 1900;
                1600 1750 2100 2450;
                650 800 1000 1600;
                1000 1000 1500 2000]

total_demand_months_delta = [4250 4750 6100 7950]

#Transport costs for finished products ($ per dcm) each month
# months as columns
trans_cost_rows = ("Alpha", "Beta", "Delta") # columns
trans_cost =[4.50 3.75 5.75 4.25;
                12.00 10.00 13.00 12.00;
                7.40 7.00 7.75 7.25]

####### Max the profit  ################

#Also report the total profit and tables for each final product showing which machines
#are used for the production in each month.

M = length(months) # months
R = length(regions) # regions
C = length(use_raw_mat_rows) # alpha, beta, delta
B = length(prod_time_columns) # blending, grading
Y = length(use_raw_mat_columns) # raw material: TSP, HCMD
W = 4 #four operators

time_month = [30 29 30 30] # days minus cleaning for may - august
storage_begin =[100 100 100]

# model
zen = Model(Gurobi.Optimizer)

# Variable for products manufactured each month
@variable(zen, x[c=1:C,m=1:M] >= 0, Int)

# Variable for sold products, months, regions
@variable(zen, y[c=1:C, m=1:M, r=1:R] >= 0, Int)

# variable for stored products c at end of month m
@variable(zen, storage_level[c=1:C,m=1:M+1] >= 0, Int)

# Machines
@variable(zen, machines[b=1:B,c=1:C, m=1:M] >= 0, Int)

# Workers
@variable(zen, workers[b=1:B,m=1:M] >= 0, Int)

@objective(zen, Max, sum(y[c,m,r]*prod_price[c,m] for c=1:C,m=1:M,r=1:R) 
                    - sum(trans_cost[c,m]*y[c,m,r] for c=1:C,m=1:M,r=1:R) 
                    - sum(prod_cost[c,m]*x[c,m] for c=1:C,m=1:M)
                    - sum(storage_level[c,m]*stor_cost[c] for c=1:C,m=1:M))


# recieved monthly raw material can not exceed the amount 
@constraint(zen, [m=1:M], sum(use_raw_mat[c,1]*x[c,m] for c=1:C) <= TSP_per_month )
@constraint(zen, [m=1:M], sum(use_raw_mat[c,2]*x[c,m] for c=1:C) <= HCMD_per_month )

# Bleending/grading time constraint for all machines 
@constraint(zen,[m=1:M, c=1:C, b=1:B], prod_time[c,b]*x[c,m] <= time_month[m]*8*machines[b,c,m])

#constraining allocated machines every month over all products
@constraint(zen, [m=1:M], sum(machines[1,c,m] for c=1:C) <= blending_machines) 
@constraint(zen, [m=1:M], sum(machines[2,c,m] for c=1:C) <= grading_machines)

# storage variable
@constraint(zen,[c=1:C], storage_level[c,1] == 100) 
@constraint(zen, [c=1:C, m=1:M], storage_level[c,m] + x[c,m] - sum(y[c,m,r] for r=1:R) == storage_level[c,m+1])

# storage constraint
@constraint(zen,[m=1:M], sum(storage_level[c,m] for c=1:C) <= 2500)

# demand constraint 
@constraint(zen,[r=1:R,m=1:M], y[1,m,r]  <=  demand_alpha[r,m])
@constraint(zen,[r=1:R,m=1:M], y[2,m,r]  <=  demand_beta[r,m])
@constraint(zen,[r=1:R,m=1:M], y[3,m,r]  <=  demand_delta[r,m])

# don't sell what you don't own now you can only sell whats on storage from previous EOM
@constraint(zen,[m=1:M,c=1:C], storage_level[c,m] >= sum(y[c,m,r] for r=1:R))

#must have 100 of each product in storage at the end of the last month
@constraint(zen,[c=1:C], storage_level[c,5] >= 100) 

#worker constraints
@constraint(zen, [m=1:M], sum(workers[b,m] for b=1:B) == 4) # We only have 4 operators each month across both types of equipment
@constraint(zen, [m=1:M], workers[1,m] * 3 == sum(machines[1,c,m] for c=1:C)) #Each blending operator can only operate 3 blending machines each month
@constraint(zen, [m=1:M], workers[2,m] * 2 == sum(machines[2,c,m] for c=1:C)) #Each grating operator can only operate 2 grating machines each month




println("Solving Model")
optimize!(zen)


for m=1:M+1
    for c=1:C
        print(value(storage_level[c,m]), " ")
    end
    print("\n")
end

# Report results
println("-------------------------------------");
if termination_status(zen) == MOI.OPTIMAL
    println("RESULTS:")
    println("objective = $(objective_value(zen))\n") 
    for c=1:C
        for m=1:M
            println(value(storage_level[c,m]))
        end
    end
else
    println(" No solution")
end
println("--------------------------------------");