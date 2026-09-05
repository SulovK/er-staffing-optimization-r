# ER Staffing Integer Linear Programming Model                        
# Objective: Maximize demand-weighted staffing under budget constraint 
library("lpSolve")

# Read and prepare the ER wait time data  
er_data <- read.csv(file.choose())

er_data$Shift <- ifelse(er_data$Time.of.Day %in% c("Early Morning", "Late Morning"), "Morning",
                        ifelse(er_data$Time.of.Day %in% c("Afternoon", "Evening"), "Afternoon",
                               ifelse(er_data$Time.of.Day %in% c("Night", "Late Night"), "Night", NA)))

er_data <- er_data[!is.na(er_data$Shift), ]

# Aggregate shift information           
patient_counts <- aggregate(
  Patient.ID ~ Shift,
  data = er_data,
  FUN = length
)

names(patient_counts)[2] <- "Total_Patients"

nurse_ratio_avg <- aggregate(
  Nurse.to.Patient.Ratio ~ Shift,
  data = er_data,
  FUN = mean
)

names(nurse_ratio_avg)[2] <- "Avg_Patients_Per_Nurse"

specialist_avg <- aggregate(
  Specialist.Availability ~ Shift,
  data = er_data,
  FUN = mean
)

names(specialist_avg)[2] <- "Avg_Historical_Specialist_Availability"

shift_summary <- merge(patient_counts, nurse_ratio_avg, by = "Shift")
shift_summary <- merge(shift_summary, specialist_avg, by = "Shift")

shift_order <- c("Morning", "Afternoon", "Night")
shift_summary <- shift_summary[match(shift_order, shift_summary$Shift), ]

print(shift_summary)

# Define staffing requirements        
required_nurses <- c(
  Morning = 4,
  Afternoon = 8,
  Night = 3
)

required_specialists <- c(
  Morning = 1,
  Afternoon = 2,
  Night = 1
)

# Define shift labor costs                
nurse_cost <- c(
  Morning = 300,
  Afternoon = 325,
  Night = 375
)

specialist_cost <- c(
  Morning = 500,
  Afternoon = 550,
  Night = 650
)

# Define available resources and budget  
total_nurses <- 40
total_specialist <- 10

available_budget <- 15000

# Demand-weighted objective function   
# Calculate each shift's proportion of total patient demand.
# Shifts with more patients receive larger objective weights.
demand_weight <- shift_summary$Total_Patients / sum(shift_summary$Total_Patients)
names(demand_weight) <- shift_summary$Shift

print(demand_weight)

# Decision variables:
# x1 = Morning nurses
# x2 = Afternoon nurses
# x3 = Night nurses
# x4 = Morning specialists
# x5 = Afternoon specialists
# x6 = Night specialists
#
# Objective:
# Maximize demand-weighted staffing.
# This encourages the model to assign more staff to shifts
# with higher patient demand.

f.obj <- c(
  demand_weight["Morning"],
  demand_weight["Afternoon"],
  demand_weight["Night"],
  demand_weight["Morning"],
  demand_weight["Afternoon"],
  demand_weight["Night"]
)

# integer linear program model        
f.con <- matrix(
  c(
    # Minimum nurse requirements
    1, 0, 0, 0, 0, 0,
    0, 1, 0, 0, 0, 0,
    0, 0, 1, 0, 0, 0,
    
    # Minimum specialist requirements
    0, 0, 0, 1, 0, 0,
    0, 0, 0, 0, 1, 0,
    0, 0, 0, 0, 0, 1,
    
    # Total available nurses and specialists
    1, 1, 1, 0, 0, 0,
    0, 0, 0, 1, 1, 1,
    
    # Specialists must be less than or equal to nurses in each shift
    # Morning: n1 - s1 >= 0
    1, 0, 0, -1, 0, 0,
    
    # Afternoon: n2 - s2 >= 0
    0, 1, 0, 0, -1, 0,
    
    # Night: n3 - s3 >= 0
    0, 0, 1, 0, 0, -1,
    
    # Afternoon nurse-to-specialist ratio:
    # At least 1 specialist per 3 nurses
    # 3s2 - n2 >= 0
    0, -1, 0, 0, 3, 0,
    
    # Budget constraint:
    # total staffing cost <= available_budget
    nurse_cost["Morning"], nurse_cost["Afternoon"], nurse_cost["Night"],
    specialist_cost["Morning"], specialist_cost["Afternoon"], specialist_cost["Night"]
  ),
  nrow = 13,
  byrow = TRUE
)

f.dir <- c(
  ">=", ">=", ">=",
  ">=", ">=", ">=",
  "<=", "<=",
  ">=", ">=", ">=",
  ">=",
  "<="
)

f.rhs <- c(
  required_nurses["Morning"],
  required_nurses["Afternoon"],
  required_nurses["Night"],
  required_specialists["Morning"],
  required_specialists["Afternoon"],
  required_specialists["Night"],
  total_nurses,
  total_specialist,
  0,
  0,
  0,
  0,
  available_budget
)

er_staffing_sol <- lp(
  direction = "max",
  objective.in = f.obj,
  const.mat = f.con,
  const.dir = f.dir,
  const.rhs = f.rhs,
  all.int = TRUE
)

# optimal staffing solution     
print(er_staffing_sol$status)

# Status 0 means the model found an optimal feasible solution.
# If status is not 0, the budget or staffing constraints may be infeasible.
print(er_staffing_sol$objval)

opt_sol <- er_staffing_sol$solution

names(opt_sol) <- c(
  "Morning_Nurses", "Afternoon_Nurses", "Night_Nurses",
  "Morning_Specialists", "Afternoon_Specialists", "Night_Specialists"
)

print(opt_sol)

# final solution table            
solution_table <- data.frame(
  Shift = shift_order,
  Total_Patients = shift_summary$Total_Patients,
  Demand_Weight = demand_weight[shift_order],
  Required_Nurses = required_nurses[shift_order],
  Assigned_Nurses = opt_sol[1:3],
  Required_Specialists = required_specialists[shift_order],
  Assigned_Specialists = opt_sol[4:6],
  Nurse_Cost_Per_Shift = nurse_cost[shift_order],
  Specialist_Cost_Per_Shift = specialist_cost[shift_order]
)

solution_table$Total_Shift_Cost <-
  solution_table$Assigned_Nurses * solution_table$Nurse_Cost_Per_Shift +
  solution_table$Assigned_Specialists * solution_table$Specialist_Cost_Per_Shift

solution_table$Total_Assigned_Staff <-
  solution_table$Assigned_Nurses + solution_table$Assigned_Specialists

print(solution_table)

# Display budget usage                
total_staffing_cost <- sum(solution_table$Total_Shift_Cost)

budget_table <- data.frame(
  Available_Budget = available_budget,
  Total_Staffing_Cost = total_staffing_cost,
  Budget_Remaining = available_budget - total_staffing_cost
)

print(budget_table)

# Compare staffing with patient demand   
staffing_distribution <- data.frame(
  Shift = shift_order,
  Patient_Share = demand_weight[shift_order],
  Staff_Assigned = solution_table$Total_Assigned_Staff,
  Staff_Share = solution_table$Total_Assigned_Staff /
    sum(solution_table$Total_Assigned_Staff)
)

print(staffing_distribution)


# SCENARIO 1
# Budget Sensitivity Analysis
# This scenario tests how staffing changes when the available budget changes.
# The objective remains the same:
# maximize demand-weighted staffing.
budget_levels <- c(10000, 12500, 15000, 17500, 20000)

budget_scenario_results <- data.frame()

for (b in budget_levels) {
  
  available_budget <- b
  
  f.rhs <- c(
    required_nurses["Morning"],
    required_nurses["Afternoon"],
    required_nurses["Night"],
    required_specialists["Morning"],
    required_specialists["Afternoon"],
    required_specialists["Night"],
    total_nurses,
    total_specialist,
    0,
    0,
    0,
    0,
    available_budget
  )
  
  budget_sol <- lp(
    direction = "max",
    objective.in = f.obj,
    const.mat = f.con,
    const.dir = f.dir,
    const.rhs = f.rhs,
    all.int = TRUE
  )
  
  opt <- budget_sol$solution
  
  total_cost <- sum(
    opt[1:3] * nurse_cost[shift_order] +
      opt[4:6] * specialist_cost[shift_order]
  )
  
  scenario_row <- data.frame(
    Budget = b,
    Status = budget_sol$status,
    Objective_Value = budget_sol$objval,
    Morning_Nurses = opt[1],
    Afternoon_Nurses = opt[2],
    Night_Nurses = opt[3],
    Morning_Specialists = opt[4],
    Afternoon_Specialists = opt[5],
    Night_Specialists = opt[6],
    Total_Nurses = sum(opt[1:3]),
    Total_Specialists = sum(opt[4:6]),
    Total_Staff = sum(opt),
    Total_Cost = total_cost,
    Budget_Remaining = b - total_cost
  )
  
  budget_scenario_results <- rbind(
    budget_scenario_results,
    scenario_row
  )
}

print(budget_scenario_results)



# SCENARIO 2
# Patient Demand Increase / Decrease
# This scenario tests how staffing changes when patient demand changes.
# Unlike changing only the objective weights, this changes the minimum
# required staffing levels.

demand_multipliers <- c(0.80, 1.00, 1.20, 1.50)

demand_scenario_results <- data.frame()

for (m in demand_multipliers) {
  
  adjusted_required_nurses <- ceiling(required_nurses * m)
  adjusted_required_specialists <- ceiling(required_specialists * m)
  
  f.rhs.demand <- c(
    adjusted_required_nurses["Morning"],
    adjusted_required_nurses["Afternoon"],
    adjusted_required_nurses["Night"],
    adjusted_required_specialists["Morning"],
    adjusted_required_specialists["Afternoon"],
    adjusted_required_specialists["Night"],
    total_nurses,
    total_specialist,
    0,
    0,
    0,
    0,
    available_budget
  )
  
  demand_sol <- lp(
    direction = "max",
    objective.in = f.obj,
    const.mat = f.con,
    const.dir = f.dir,
    const.rhs = f.rhs.demand,
    all.int = TRUE
  )
  
  opt <- demand_sol$solution
  
  total_cost <- sum(
    opt[1:3] * nurse_cost[shift_order] +
      opt[4:6] * specialist_cost[shift_order]
  )
  
  scenario_row <- data.frame(
    Demand_Multiplier = m,
    Status = demand_sol$status,
    Objective_Value = demand_sol$objval,
    Morning_Nurses = opt[1],
    Afternoon_Nurses = opt[2],
    Night_Nurses = opt[3],
    Morning_Specialists = opt[4],
    Afternoon_Specialists = opt[5],
    Night_Specialists = opt[6],
    Total_Nurses = sum(opt[1:3]),
    Total_Specialists = sum(opt[4:6]),
    Total_Staff = sum(opt),
    Total_Cost = total_cost,
    Budget_Remaining = available_budget - total_cost
  )
  
  demand_scenario_results <- rbind(
    demand_scenario_results,
    scenario_row
  )
}

print(demand_scenario_results)


# SCENARIO 3
# Nurse Availability Shortage
# This scenario tests how staffing changes when the total number of available nurses changes.
# The objective remains the same:
# maximize demand-weighted staffing.
nurse_availability_levels <- c(20, 25, 30, 35, 40)

nurse_availability_results <- data.frame()

for (nurse_limit in nurse_availability_levels) {
  
  f.rhs.nurse <- c(
    required_nurses["Morning"],
    required_nurses["Afternoon"],
    required_nurses["Night"],
    required_specialists["Morning"],
    required_specialists["Afternoon"],
    required_specialists["Night"],
    nurse_limit,
    total_specialist,
    0,
    0,
    0,
    0,
    available_budget
  )
  
  nurse_sol <- lp(
    direction = "max",
    objective.in = f.obj,
    const.mat = f.con,
    const.dir = f.dir,
    const.rhs = f.rhs.nurse,
    all.int = TRUE
  )
  
  opt <- nurse_sol$solution
  
  total_cost <- sum(
    opt[1:3] * nurse_cost[shift_order] +
      opt[4:6] * specialist_cost[shift_order]
  )
  
  scenario_row <- data.frame(
    Nurse_Availability = nurse_limit,
    Status = nurse_sol$status,
    Objective_Value = nurse_sol$objval,
    Morning_Nurses = opt[1],
    Afternoon_Nurses = opt[2],
    Night_Nurses = opt[3],
    Morning_Specialists = opt[4],
    Afternoon_Specialists = opt[5],
    Night_Specialists = opt[6],
    Total_Nurses = sum(opt[1:3]),
    Total_Specialists = sum(opt[4:6]),
    Total_Staff = sum(opt),
    Total_Cost = total_cost,
    Budget_Remaining = available_budget - total_cost
  )
  
  nurse_availability_results <- rbind(
    nurse_availability_results,
    scenario_row
  )
}

print(nurse_availability_results)