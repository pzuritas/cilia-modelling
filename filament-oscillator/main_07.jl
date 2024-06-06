include("src/utils/integral.jl")
using .Integral
using DifferentialEquations
using ODEInterfaceDiffEq

include("src/models/solver.jl")


# All lengths are given divided by a
# All times are given divided by T

# Single cilium geomerty
a = 1.0  # Sphere radius, reference
N = 11  # Number of discretisation spheres per cilium
sphere_space = 0.2  # Fraction of radii between spheres
L = N*(2 + sphere_space)*a  # Cilium length w/r to sphere radius

# Cilia system geomerty
M = 2  # Number of cilia
d = 3*N  # Amount of radii between cilia
φ = 0.0 # 12.5*π/180.0  # Angle of cilia beat plane

# Single cilium reference beat dynamics
T = 1.0  # Beat period, reference
θ_0 = π/2.1  # Maximum bending angle
f_eff = 0.3  # Effective stroke fraction
f_ψ = 0.85  # Fraction of recovery controlled by travelling wave
f_w = 0.4  # Travelling wavelength w/r to cilium length
orientation = π/2.0  # Normal to attachment plane

# Fluid dynamics
μ = 1.0  # Fluid viscosity, reference
κ_tilde = 1e3  # Ratio of bending stiffness to viscous drag
κ_b = κ_tilde*μ*T  # bending stiffness

# Initial phase
Ψ₀ = repeat([2π, 0.0], outer=[M])

# Simulation parameters
num_periods = 10
# alg = Trapezoid(autodiff=false)
alg = Euler()
# Number of timesteps. Set to 0 if using adaptive timestepping
num_steps = 15000
# num_steps = 0

# Define background flow
function u(t::Real)
    return [0., 0., 0.]
end

# Integration rule
rule = GaussLegendre(15)

# Instance objects
beat_params = BeatParameters(L, T, θ_0, f_eff, f_ψ, f_w, orientation, rule)
h = L/(N - 1)
sim_params = SimulationParameters(M, N, φ, d, a, κ_b)
x₀ = [[(j - 1)*d, 0.0, 0.0] for j=1:M]
s = [(i)*h for i=1:N]
A = [cos(φ) -sin(φ) 0.0; sin(φ) cos(φ) 0.0; 0.0 0.0 1.0]
system = CiliaSystem(
    beat_params,
    sim_params,
    x₀,
    s,
    A,
    Ψ₀,
    u
)
fluid = FluidParameters(μ)

# Run the system
data, solution = run_system(system, fluid, num_periods*T, alg, num_steps)

# Runs correctly!