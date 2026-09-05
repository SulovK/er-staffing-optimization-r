# Emergency Room Staffing Optimization with R

An integer linear programming project that uses patient demand patterns to allocate nurses and specialists across emergency room shifts while respecting staffing, availability, and budget constraints.

## Project overview

Emergency departments need enough staff to provide timely care, but staffing decisions are limited by labor costs and employee availability. This project analyzes 5,000 simulated emergency room visits and builds an integer linear programming model in R to recommend a demand-based staffing plan for morning, afternoon, and night shifts.

The analysis addresses the following question:

> How can an emergency room allocate nurses and specialists across shifts to better match patient demand while staying within budget and staffing limits?

## Key results

- The afternoon shift accounted for 64.54% of patient visits, compared with 24.86% in the morning and 10.60% at night.
- Under the $15,000 base budget, the model assigned 29 nurses and 10 specialists.
- The recommended plan allocated 29 of the 39 total staff members to the afternoon shift, where demand was highest.
- The model used the full base budget, making budget a binding constraint.
- Budget sensitivity analysis showed that staffing increased as the budget grew, but additional funding stopped helping once the available workforce was fully assigned.
- Nurse availability emerged as a major operational bottleneck.

## Recommended staffing plan

| Shift | Nurses | Specialists | Total staff | Shift cost |
|---|---:|---:|---:|---:|
| Morning | 5 | 1 | 6 | $2,000 |
| Afternoon | 21 | 8 | 29 | $11,225 |
| Night | 3 | 1 | 4 | $1,775 |
| **Total** | **29** | **10** | **39** | **$15,000** |

## Analytical approach

1. Clean and group patient records into morning, afternoon, and night shifts.
2. Aggregate patient volume, nurse-to-patient ratios, and specialist availability by shift.
3. Calculate demand weights from each shift's share of total visits.
4. Formulate an integer linear programming model with six decision variables: the number of nurses and specialists assigned to each shift.
5. Optimize demand-weighted staffing subject to minimum coverage, workforce availability, staff-mix rules, and a labor budget.
6. Test how the recommended allocation changes under different budgets, demand levels, and nurse availability limits.

## Model constraints

The optimization model includes:

- Minimum nurse and specialist coverage for every shift
- A maximum of 40 nurses and 10 specialists
- A $15,000 base staffing budget
- No more specialists than nurses on any shift
- At least one afternoon specialist for every three afternoon nurses
- Whole-number staffing decisions

## Tools and skills demonstrated

- R
- `lpSolve`
- Data cleaning and aggregation
- Exploratory demand analysis
- Integer linear programming
- Constraint modeling
- Scenario and sensitivity analysis
- Translating model output into operational recommendations

## Repository contents

```text
.
├── Project.R
├── MSBA 204_Final Report.docx.pdf
└── README.md
```

## Data source

The project uses the [ER Wait Time Dataset on Kaggle](https://www.kaggle.com/datasets/rivalytics/er-wait-time), which contains 5,000 simulated patient visits.

The dataset is not included in this repository. Download the CSV from Kaggle before running the analysis.

## How to run the analysis

1. Install R and the required package:

   ```r
   install.packages("lpSolve")
   ```

2. Download the dataset from Kaggle.
3. Open `Project.R` in RStudio or another R environment.
4. Run the script. When prompted by `file.choose()`, select the downloaded CSV file.

The script prints the shift-level demand summary, optimal staffing allocation, budget use, and results from three sensitivity analyses.

## Business recommendations

- Concentrate staffing on the afternoon shift while maintaining minimum coverage during lower-demand periods.
- Use float-pool, part-time, or on-call staff to respond to changes in demand.
- Pair budget increases with recruiting or scheduling capacity; funding alone cannot improve coverage once staff availability becomes binding.
- Re-estimate demand and rerun the model as new patient data becomes available.

## Limitations

This is a decision-support model based on simulated data and assumed labor costs. It does not include patient acuity, physicians, room capacity, staff scheduling rules, breaks, individual qualifications, or uncertainty in future arrivals. Its recommendations should therefore be treated as a starting point for operational planning rather than a production staffing schedule.

## Authors

Sulov Khadka and Ruchika Rakesh Singh  
MSBA 204: Decision Analytics  
California State University, Sacramento
