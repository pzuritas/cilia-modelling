using LinearAlgebra
using LinearSolve
using DifferentialEquations
using Plots


include("TangentAngleBeat.jl")
include("../stokes/GreensFunctions.jl")

μ = 1.0
a = 7e-2

N = 25
h = L/(N - 1)
s = [(i)*h for i=1:N]

function R(ψ_2::Real)
    return [cos(ψ_2) 0. -sin(ψ_2); 0. 1. 0.; sin(ψ_2) 0. cos(ψ_2)]
end

function x(s::Real, ψ::Vector)
    return R(ψ[2])*ξ(s, ψ[1])
end

function dR_dψ_2(ψ_2::Real)
    return [-sin(ψ_2) 0. -cos(ψ_2); 0. 1. 0.; cos(ψ_2) 0. -sin(ψ_2)]
end

function K(s::Real, ψ::Vector)
    return [R(ψ[2])*dξ_dψ_1(s, ψ[1]) dR_dψ_2(ψ[2])*ξ(s, ψ[1])]
end

function Kₕ(ψ::Vector)
    return cat([K(s[i], ψ) for i = 1:N]..., dims=1)
end

function Mₕ(ψ::Vector, μ::Real, a::Real)
    mobility = zeros(3*N, 3*N)
    for i = 1:N
        for j = 1:N
            α = 1 + 3*(i - 1)
            β = 1 + 3*(j - 1)
            mobility[α:(α + 2), β:(β + 2)] .= rotne_prager_blake_tensor(
                x(s[i], ψ), x(s[j], ψ), μ, a
            )
        end
    end
    return mobility
end

function q_ref(ψ::Vector, μ::Real, a::Real)
    return Kₕ(ψ)'*inv(Mₕ(ψ, μ, a))*Kₕ(ψ)*[2.0*π/T, 0.0]
end

function ψ_dot(ψ::Vector, μ::Real, a::Real)
    q = q_ref(ψ, μ, a)
    matrix = [Mₕ(ψ, μ, a) -Kₕ(ψ); -Kₕ(ψ)' zeros(2, 2)]
    rhs = vcat(zeros(3*N), -q)
    problem = LinearProblem(matrix, rhs)
    solution = solve(problem, KrylovJL_GMRES())
    dψ_dt = solution.u[end-1:end]
    return dψ_dt
end

function filament_oscillator!(dψ_dt::Vector, ψ::Vector, p::NamedTuple, t::Real)
    μ = p.μ
    a = p.a
    rhs = ψ_dot(ψ, μ, a)
    dψ_dt[1] = rhs[1]
    dψ_dt[2] = rhs[2]
    return nothing
end

function run_filament(p::NamedTuple, final_time::Real, num_steps::Int)
    t_span = (0.0, final_time)
    problem = ODEProblem(filament_oscillator!, [π, 0.0], t_span, p)
    solution = solve(problem, AB4(), dt=final_time/num_steps)
    return solution
end

function plot_solution(solution::ODESolution)
    ψ_array = solution.u
    p = plot(
        xlim=(-L+1.0, L+1.0), ylim=(-L/2., L+1.0), title="Filament movement",
        xaxis="x [μm]", yaxis="z [μm]", legend=false
    )
    color_scheme = palette(:twilight, size(ψ_array)[1], rev=true)
    i = 1
    for (i, ψ) in enumerate(ψ_array)
        positions = zeros(N, 3)
        for j=1:N
            positions[j, :] += x(s[j], ψ)
        end
        plot!(positions[:, 1], positions[:, 3], color=color_scheme[i])
        i += 1
    end
    display(p)
    return nothing
end

function plot_trajectory(solution::ODESolution)
    ψ_array = stack(solution.u, dims=1)
    t = solution.t
    p = plot(title="Phase evolution", xaxis="t [ms]")
    plot!(t, ψ_array[:, 1], label="ψ₁")
    plot!(t, ψ_array[:, 2], label="ψ₂")
    display(p)
    return nothing
end

p = (a=a, μ=μ)

solution = run_filament(p, T, 100)
# plot_solution(solution)
# plot_trajectory(solution)
