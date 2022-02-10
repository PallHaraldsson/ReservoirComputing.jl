abstract type AbstractReservoir end

function get_ressize(reservoir::AbstractReservoir)
    reservoir.res_size
end

function get_ressize(reservoir)
    size(reservoir, 1)
end

struct RandSparseReservoir{S,T,C} <: AbstractReservoir
    res_size::S
    radius::T
    sparsity::C
end

"""
    RandSparseReservoir(res_size, radius, sparsity)
    RandSparseReservoir(res_size; radius=1.0, sparsity=0.1)

Returns a random sparse reservoir initializer, that will return a matrix with given `sparsity` and 
scaled spectral radius according to `radius`. This is the default choice in the ```ESN``` construction.
"""
function RandSparseReservoir(res_size; radius=1.0, sparsity=0.1)
    RandSparseReservoir(res_size, radius, sparsity)
end

"""
    create_reservoir(reservoir::AbstractReservoir, res_size)
    create_reservoir(reservoir, args...)

Given an ```AbstractReservoir` constructor and the reservoir size it returns the corresponding matrix.
Alternatively it accepts a given matrix.
"""
function create_reservoir(reservoir::RandSparseReservoir, res_size)
    reservoir_matrix = Matrix(sprand(Float64, res_size, res_size, reservoir.sparsity))
    reservoir_matrix = 2.0 .*(reservoir_matrix.-0.5)
    replace!(reservoir_matrix, -1.0=>0.0)
    rho_w = maximum(abs.(eigvals(reservoir_matrix)))
    reservoir_matrix .*= reservoir.radius/rho_w
    sparse(reservoir_matrix)
end

function create_reservoir(reservoir, args...)
    reservoir
end

#=
function create_reservoir(res_size, reservoir::RandReservoir)
    sparsity = degree/res_size
    W = Matrix(sprand(Float64, res_size, res_size, sparsity))
    W = 2.0 .*(W.-0.5)
    replace!(W, -1.0=>0.0)
    rho_w = maximum(abs.(eigvals(W)))
    W .*= radius/rho_w
    W
end
=#    

#SVD reservoir construction based on "Yang, Cuili, et al. "Design of polynomial echo state networks for time series prediction" Yang et al
struct PseudoSVDReservoir{S,T,C} <: AbstractReservoir
    res_size::S
    max_value::T
    sparsity::C
    sorted::Bool
    reverse_sort::Bool
end

function PseudoSVDReservoir(res_size; max_value=1.0, sparsity=0.1, sorted=true, reverse_sort=false)
    PseudoSVDReservoir(res_size, max_value, sparsity, sorted, reverse_sort)
end

"""
    PseudoSVDReservoir(max_value, sparsity, sorted, reverse_sort)
    PseudoSVDReservoir(max_value, sparsity; sorted=true, reverse_sort=false)

Returns an initializer to build a sparse reservoir matrix, with given ```sparsity``` created using SVD as described in [1]. 

[1] Yang, Cuili, et al. "_Design of polynomial echo state networks for time series prediction._" Neurocomputing 290 (2018): 148-160.
"""
function PseudoSVDReservoir(res_size, max_value, sparsity; sorted=true, reverse_sort=false)
    PseudoSVDReservoir(res_size, max_value, sparsity, sorted, reverse_sort)
end

function create_reservoir(reservoir::PseudoSVDReservoir, res_size)
    reservoir_matrix = create_diag(res_size, reservoir.max_value, sorted = reservoir.sorted, reverse_sort = reservoir.reverse_sort)
    tmp_sparsity = get_sparsity(reservoir_matrix, res_size)

    while tmp_sparsity <= reservoir.sparsity
        reservoir_matrix *= create_qmatrix(res_size, rand(1:res_size), rand(1:res_size), rand()*2-1)
        tmp_sparsity = get_sparsity(reservoir_matrix, res_size)
    end
    sparse(reservoir_matrix)
end

function create_diag(dim, max_value; sorted = true, reverse_sort = false)

    diagonal_matrix = zeros(Float64, dim, dim)
    if sorted == true
        if reverse_sort == true
            diagonal_values = sort(rand(Float64, dim).*max_value, rev = true)
            diagonal_values[1] = max_value
        else
            diagonal_values = sort(rand(Float64, dim).*max_value)
            diagonal_values[end] = max_value
        end
    else
        diagonal_values = rand(Float64, dim).*max_value
    end

    for i=1:dim
        diagonal_matrix[i, i] = diagonal_values[i]
    end
    diagonal_matrix
end

function create_qmatrix(dim, coord_i, coord_j, theta)

    qmatrix = zeros(Float64, dim, dim)
    for i = 1:dim
        qmatrix[i,i] = 1.0
    end
    qmatrix[coord_i, coord_i] = cos(theta)
    qmatrix[coord_j, coord_j] = cos(theta)
    qmatrix[coord_i, coord_j] = -sin(theta)
    qmatrix[coord_j, coord_i] = sin(theta)

    qmatrix
end

function get_sparsity(M, dim)
    size(M[M .!= 0], 1)/(dim*dim-size(M[M .!= 0], 1)) #nonzero/zero elements
end

#from "minimum complexity echo state network" Rodan
# Delay Line Reservoir


struct DelayLineReservoir{S,T} <: AbstractReservoir
    res_size::S
    weight::T
end

"""
    DelayLineReservoir(res_size, weight)
    DelayLineReservoir(res_size; weight=0.1)

Returns a Delay Line Reservoir matrix constructor to obtain a deterministi reservoir as described in [1]. The 
```weight``` can be passed as arg or kwarg and it determines the absolute value of all the connections in the reservoir.

[1] Rodan, Ali, and Peter Tino. "_Minimum complexity echo state network._" IEEE transactions on neural networks 22.1 (2010): 131-144.
"""
function DelayLineReservoir(res_size; weight=0.1)
    DelayLineReservoir(res_size, weight)
end

function create_reservoir(reservoir::DelayLineReservoir, res_size)

    reservoir_matrix = zeros(Float64, res_size, res_size)
    for i=1:res_size-1
        reservoir_matrix[i+1,i] = reservoir.weight
    end
    sparse(reservoir_matrix)
end

#from "minimum complexity echo state network" Rodan
# Delay Line Reservoir with backward connections
struct DelayLineBackwardReservoir{S,T} <: AbstractReservoir
    res_size::S
    weight::T
    fb_weight::T
end

"""
    DelayLineBackwardReservoir(res_size, weight, fb_weight)
    DelayLineBackwardReservoir(res_size; weight=0.1, fb_weight=0.2)

Returns a Delay Line Reservoir constructor to create a matrix with Backward connections as described in [1]. The 
```weight``` and ```fb_weight``` can be passed as either args or kwargs, and they determine the only absolute values
of the connections in the reservoir.

[1] Rodan, Ali, and Peter Tino. "_Minimum complexity echo state network._" IEEE transactions on neural networks 22.1 (2010): 131-144.
"""
function DelayLineBackwardReservoir(res_size; weight=0.1, fb_weight=0.2)
    DelayLineBackwardReservoir(res_size, weight, fb_weight)
end

function create_reservoir(reservoir::DelayLineBackwardReservoir, res_size)

    reservoir_matrix = zeros(Float64, res_size, res_size)
    for i=1:res_size-1
        reservoir_matrix[i+1,i] = reservoir.weight
        reservoir_matrix[i,i+1] = reservoir.fb_weight
    end
    sparse(reservoir_matrix)
end

#from "minimum complexity echo state network" Rodan
# Simple cycle reservoir
struct SimpleCycleReservoir{S,T} <: AbstractReservoir
    res_size::S
    weight::T
end

"""
    SimpleCycleReservoir(res_size, weight)
    SimpleCycleReservoir(res_size; weight=0.1)

Returns a Simple Cycle Reservoir Reservoir constructor to biuld a reservoir matrix as described in [1]. The 
```weight``` can be passed as arg or kwarg and it determines the absolute value of all the connections in the reservoir.

[1] Rodan, Ali, and Peter Tino. "Minimum complexity echo state network." IEEE transactions on neural networks 22.1 (2010): 131-144.
"""
function SimpleCycleReservoir(res_size; weight=0.1)
    SimpleCycleReservoir(res_size, weight)
end

function create_reservoir(reservoir::SimpleCycleReservoir, res_size)

    reservoir_matrix = zeros(Float64, res_size, res_size)
    for i=1:res_size-1
        reservoir_matrix[i+1,i] = reservoir.weight
    end
    reservoir_matrix[1, res_size] = reservoir.weight
    sparse(reservoir_matrix)
end

#from "simple deterministically constructed cycle reservoirs with regular jumps" by Rodan and Tino
# Cycle Reservoir with Jumps
struct CycleJumpsReservoir{S,T,C} <: AbstractReservoir
    res_size::S
    cycle_weight::T
    jump_weight::T
    jump_size::C
end

"""
    CycleJumpsReservoir(res_size; cycle_weight=0.1, jump_weight=0.1, jump_size=3)
    CycleJumpsReservoir(res_size, cycle_weight, jump_weight, jump_size)

Return a Cycle Reservoir with Jumps constructor to create a reservoir matrix as described in [1]. The 
```weight``` and ```jump_weight``` can be passed as args or kwargs and they determine the absolute values of 
all the connections in the reservoir. The ```jump_size``` can also be passed either as arg and kwarg and it 
detemines the jumps between ```jump_weight```s.

[1] Rodan, Ali, and Peter Tiňo. "_Simple deterministically constructed cycle reservoirs with regular jumps._" Neural computation 24.7 (2012): 1822-1852.
"""
function CycleJumpsReservoir(res_size; cycle_weight=0.1, jump_weight=0.1, jump_size=3)
    CycleJumpsReservoir(res_size, cycle_weight, jump_weight, jump_size)
end

function create_reservoir(reservoir::CycleJumpsReservoir, res_size)

    reservoir_matrix = zeros(res_size, res_size)
    for i=1:res_size-1
        reservoir_matrix[i+1,i] = reservoir.cycle_weight
    end
    reservoir_matrix[1, res_size] = reservoir.cycle_weight

    for i=1:reservoir.jump_size:res_size-reservoir.jump_size
        tmp = (i+reservoir.jump_size)%res_size

        if tmp == 0
            tmp = res_size
        end

        reservoir_matrix[i, tmp] = reservoir.jump_weight
        reservoir_matrix[tmp, i] = reservoir.jump_weight
    end
    sparse(reservoir_matrix)
end


"""
    NullReservoir()

Return a constructor for a matrix `zeros(res_size, res_size)`
"""
struct NullReservoir <: AbstractReservoir end

function create_reservoir(reservoir::NullReservoir, res_size)
    zeros(res_size, res_size)
end

