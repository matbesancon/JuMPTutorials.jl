#' ---
#' title: Benders Decomposition
#' ---

#' **Originally Contributed by**: Shuvomoy Das Gupta

#' This notebook describes how to implement Benders decomposition in JuMP, which is a large scale optimization scheme. 
#' We only discuss the classical approach (using loops) here.
#' The approach using lazy constraints is showed in the correponding notebook.
 
#' To illustrate an implementation of the Benders decomposition in JuMP,
#' we apply it to the following general mixed integer problem:

#' \begin{align*}
#' & \text{maximize} \quad &&c_1^T x+c_2^T v \\
#' & \text{subject to} \quad &&A_1 x+ A_2 v \preceq b \\
#' & &&x \succeq 0, x \in \mathbb{Z}^n \\
#' & &&v \succeq 0, v \in \mathbb{R}^p \\
#' \end{align*}

#' where $b \in \mathbb{R}^m$, $A_1 \in \mathbb{R}^{m \times n}$, $A_2 \in \mathbb{R}^{m \times p}$ and
#' \mathbb{Z} is the set of integers. 
#' Here the symbol $\succeq$ ($\preceq$) stands for element-wise greater (less) than or equal to. 
#' Any mixed integer programming problem can be written in the form above.

#' We want to write the Benders decomposition algorithm for the problem above. 
#' Consider the polyhedron $\{u \in \mathbb{R}^m| A_2^T u \succeq 0, u \succeq 0\}$. 
#' Assume the set of vertices and extreme rays of the polyhedron is denoted by $P$ and $Q$ respectively. 
#' Assume on the $k$th iteration the subset of vertices of the polyhedron mentioned is denoted by 
#' $T(k)$ and the subset of extreme rays are denoted by $Q(k)$, 
#' which will be generated by the Benders decomposition problem below.


#' ### Benders decomposition algorithm

#' **Step 1 (Initialization)** 

#' We start with $T(1)=Q(1)=\emptyset$. 
#' Let $f_m^{(1)}$ be arbitrarily large and $x^{(1)}$ be any non-negative integer vector and go to Step 2.

#' **Step 2 (Solving the master problem)**

#' Solve the master problem, $f_\text{m}^{(k)}$ =
 
#' \begin{align*}
#' &\text{maximize} &&\quad t \\
#' &\text{subject to} \quad &&\forall \bar{u} \in T(k) \qquad t + (A_1^T \bar{u} - c_1)^T x \leq b^T \bar{u} \\
#' & && \forall \bar{y} \in Q(k) \qquad (A_1 ^T \bar{y})^T x \leq b^T \bar{y} \\
#' & && \qquad \qquad \qquad \; x \succeq 0, x \in \mathbb{Z}^n
#' \end{align*}

#' Let the maximizer corresponding to the objective value $f_\text{m}^{(k)}$ be denoted by $x^{(k)}$. 
#' Now there are three possibilities:
 
#' - If $f_\text{m}^{(k)}=-\infty$, i.e., the master problem is infeasible, 
#' then the original proble is infeasible and sadly, we are done.
#'
#' - If $f_\text{m}^{(k)}=\infty$, i.e. the master problem is unbounded above, 
#' then we take $f_\text{m}^{(k)}$ to be arbitrarily large and $x^{(k)}$ to be a corresponding feasible solution. 
#' Go to Step 3
#'
#' - If $f_\text{m}^{(k)}$ is finite, then we collect $t^{(k)}$ and $x^{(k)}$ and go to Step 3.

#' **Step 3 (Solving the subproblem and add Benders cut when needed)**

#' Solve the subproblem, $f_s(x^{(k)})$ =
 
#' \begin{align*}
#'   c_1^T x^{(k)} + & \text{minimize} &&  (b-A_1 x^{(k)})^T u \\
#'   & \text{subject to} && A_2^T u \succeq c_2 \\
#'   & && u \succeq 0, u \in \mathbb{R}^m
#' \end{align*}
 
#' Let the minimizer corresponding to the objective value $f_s(x^{(k)})$ be denoted by $u^{(k)}$. There are three possibilities:
 
#' - If $f_s(x^{(k)}) = \infty$, the original problem is either infeasible or unbounded. 
#' We quit from Benders algorithm and use special purpose algorithm to find a feasible solution if there exists one.
#'
#' - If $f_s(x^{(k)}) = - \infty$, we arrive at an extreme ray $y^{(k)}$. 
#' We add the Benders cut corresponding to this extreme ray $(A_1 ^T y^{(k)})^T x \leq b^T y^{(k)}$ to the master problem 
#' i.e., $Q(k+1):= Q(k) \cup \{y^{(k)}\}$. Take $k:=k+1$ and go to Step 3. 
#'
#' - If $f_s(x^{(k)})$ is finite, then 
#'
#'  * If $f_s(x^{(k)})=f_m^{(k)}$ we arrive at the optimal solution. 
#' The optimum objective value of the original problem is $f_s(x^{(k)})=f_m^{(k)}$, 
#' an optimal $x$ is $x^{(k)}$ and an optimal $v$ is the dual values for the second constraints of the subproblem. We are happily done!
#'
#'  * If $f_s(x^{(k)}) < f_m^{(k)}$ we get an suboptimal vertex $u^{(k)}$. 
#' We add the corresponding Benders cut $u_0 + (A_1^T u^{(k)} - c_1)^T x \leq b^T u^{(k)}$ to the master problem, i.e., $T(k+1) := T(k) \cup \{u^{(k)}\}$. Take $k:=k+1$ and go to Step 3.

#' For a more general approach to Bender's Decomposition you can have a look at 
#' [Mathieu Besançon's blog](https://matbesancon.github.io/post/2019-05-08-simple-benders/).

#' ## Data for the problem

#' The input data is from page 139, Integer programming by Garfinkel and Nemhauser[[1]](#c1).

c1 = [-1; -4]
c2 = [-2; -3]

dim_x = length(c1)
dim_u = length(c2)

b = [-2; -3]

A1 = [1 -3;
     -1 -3]
A2 = [1 -2;
     -1 -1]

M = 1000;
 
#' ## How to implement the Benders decomposition algorithm in JuMP

#' There are two ways we can implement Benders decomposition in JuMP: 
#' - *Classical approach:* Adding the Benders cuts in a loop,  and
#' - *Modern approach:* Adding the Benders cuts as lazy constraints.

#' The classical approach might be inferior to the modern one, as the solver
#' - might revisit previously eliminated solution, and
#' - might discard the optimal solution to the original problem in favor of a better but 
#' ultimately infeasible solution to the relaxed one.
 
#' For more details on the comparison between the two approaches, see [Paul Rubin's blog on Benders Decomposition](http://orinanobworld.blogspot.ca/2011/10/benders-decomposition-then-and-now.html).
 
#' ## Classical Approach: Adding the Benders Cuts in a Loop

#' Let's describe the master problem first. Note that there are no constraints, which we will added later using Benders decomposition.
 

# Loading the necessary packages
#-------------------------------
using JuMP 
using GLPK
using LinearAlgebra
using Test

# Master Problem Description
# --------------------------

master_problem_model = Model(GLPK.Optimizer)

# Variable Definition 
# ----------------------------------------------------------------
@variable(master_problem_model, 0 <= x[1:dim_x] <= 1e6, Int) 
@variable(master_problem_model, t <= 1e6)

# Objective Setting
# -----------------
@objective(master_problem_model, Max, t)
global iter_num = 1

print(master_problem_model)

#' Here is the loop that checks the status of the master problem and the subproblem and 
#' then adds necessary Benders cuts accordingly. 

iter_num = 1

while(true)
    println("\n-----------------------")
    println("Iteration number = ", iter_num)
    println("-----------------------\n")
    println("The current master problem is")
    print(master_problem_model)
     
    optimize!(master_problem_model)
    
    t_status = termination_status(master_problem_model)
    p_status = primal_status(master_problem_model)
    
    if p_status == MOI.INFEASIBLE_POINT
        println("The problem is infeasible :-(")
        break
    end

    (fm_current, x_current) = if t_status == MOI.INFEASIBLE_OR_UNBOUNDED
        (M, M * ones(dim_x))        
    elseif p_status == MOI.FEASIBLE_POINT
        (value(t), value.(x))
    else
        error("Unexpected status: $((t_status, p_status))")
    end

    println("Status of the master problem is ", t_status, 
            "\nwith fm_current = ", fm_current, 
            "\nx_current = ", x_current)

    sub_problem_model = Model(GLPK.Optimizer)

    c_sub = b - A1 * x_current

    @variable(sub_problem_model, u[1:dim_u] >= 0)

    @constraint(sub_problem_model, constr_ref_subproblem[j = 1:size(A2, 2)], dot(A2[:, j], u) >= c2[j])
    # The second argument of @constraint macro,
    # constr_ref_subproblem[j=1:size(A2,2)] means that the j-th constraint is
    # referenced by constr_ref_subproblem[j].
    
    @objective(sub_problem_model, Min, dot(c1, x_current) + dot(c_sub, u))

    print("\nThe current subproblem model is \n", sub_problem_model)

    optimize!(sub_problem_model)

    t_status_sub = termination_status(sub_problem_model)
    p_status_sub = primal_status(sub_problem_model)

    fs_x_current = objective_value(sub_problem_model) 

    u_current = value.(u)

    γ = dot(b, u_current)

    println("Status of the subproblem is ", t_status_sub, 
        "\nwith fs_x_current = ", fs_x_current, 
        "\nand fm_current = ", fm_current) 
    
    if p_status_sub == MOI.FEASIBLE_POINT && fs_x_current == fm_current # we are done
        println("\n################################################")
        println("Optimal solution of the original problem found")
        println("The optimal objective value t is ", fm_current)
        println("The optimal x is ", x_current)
                println("The optimal v is ", dual.(constr_ref_subproblem))
        println("################################################\n")
        break
    end  
    
    if p_status_sub == MOI.FEASIBLE_POINT && fs_x_current < fm_current
        println("\nThere is a suboptimal vertex, add the corresponding constraint")
        cv = A1' * u_current - c1
        @constraint(master_problem_model, t + dot(cv, x) <= γ)
        println("t + ", cv, "ᵀ x <= ", γ)
    end 
    
    if t_status_sub == MOI.INFEASIBLE_OR_UNBOUNDED
        println("\nThere is an  extreme ray, adding the corresponding constraint")
        ce = A1'* u_current
        @constraint(master_problem_model, dot(ce, x) <= γ)
        println(ce, "ᵀ x <= ", γ)
    end
    
    global iter_num += 1
end

@test value(t) ≈ -4

#' ### References
#' <a id='c1'></a>
#' 1. Garfinkel, R. & Nemhauser, G. L. Integer programming. (Wiley, 1972).
