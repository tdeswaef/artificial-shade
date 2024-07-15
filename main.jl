using Pkg
Pkg.activate(".")
#Pkg.instantiate()


using VirtualPlantLab
using ColorTypes # for the color of each mesh
import GLMakie # For 3D rendering (native OpenGL backend)# Import rather than "using" to avoid masking Scene
using SkyDomes
using RData
using DataFrames
using CSV

#---------------------------#
# read the light input data #
#---------------------------#
DataForModel = load("input/DataForModel.rds")

#-------------------#
# set the raytracer #
#-------------------#
function create_raytracer(scene, sources)
    settings = RTSettings(pkill = 0.9, maxiter = 4, nx = 1, ny = 1, parallel = true)
    RayTracer(scene, sources, settings = settings, acceleration = BVH,
                     rule = SAH{3}(5, 10));
end

#-------------------------------#
# Design the field with the net #
#-------------------------------#
Net_length = 30.0
Net_width = 3.0 #checked
Net_height = 2.5 #checked 2.5 for sensor comparison, 3.5 for sensor data
Net_transparency = 0.5
Pole_distance = Net_length/2.0
Field_width = 24.0
Field_length = 20.0
Soil_resolution = 1.0 # size of the soil tiles
Net_orientation = 0.0 
Sun_orientation = - 25.65 *(pi/180) #mimicking the orientation of the net from north

include("design_field.jl")


#----------------------#
# Visualize the set-up #
#----------------------#
render(sc_total, wireframe = false)

#-----------------------------------------------#
# run the simulation for single timepoint (154) #
#-----------------------------------------------#

# empty dataframe for storing results of absorbed power by the tiles
out_df = DataFrame(Timestamp = [], pos_x = [], pos_y =[], power = [])

#empty dataframe for storing power absorbed by the shading net
net_df = DataFrame(Timestamp = [], power = [])

for i in 154:154  # sunny day : 146:162
    # get input data from light dataframe
    Ig = DataForModel.Rg[i];
    Idir = DataForModel.I_dir[i];
    Idif = DataForModel.I_diff[i];
    theta = DataForModel.theta[i];
    phi_1 = DataForModel.phi[i] - Sun_orientation;
    phi = ifelse(phi_1 < 0, phi_1 + pi/2, ifelse(phi_1 > 2*pi, phi_1 - 2*pi, phi_1)) 
    
    # create sources for diffuse and direct light
    sources = sky(sc_total, 
    Idir = Idir, # Direct solar radiation from above
    theta_dir = theta, # complement from solar angle to zenith (theta = high when sun is low ;-))
    phi_dir = phi , # ranges between 0 and 2pi where 0 = N, pi = S
    nrays_dir = 100_000, # Number of rays for direct solar radiation
    Idif = Idif, # Diffuse solar radiation from above
    nrays_dif = 1_000_000, # Total number of rays for diffuse solar radiation
    sky_model = StandardSky, # Angular distribution of solar radiation
    dome_method = equal_solid_angles, # Discretization of the sky dome
    ntheta = 9, # Number of discretization steps in the zenith angle
    nphi = 12);

    # create and run the raytracer
    rtobj   = create_raytracer_fast(sc_total, sources)
    @time trace!(rtobj)
    
    #collect the absorbed power per tile and for the net
    alltiles = apply(field_graph, Query(ShadeNet.Tile))
    Radiation = [power(t.material)[1] for t in alltiles]
    x_pos = [t.pos_x for t in alltiles]
    y_pos = [t.pos_y for t in alltiles]
    i_df = DataFrame(Timestamp = DataForModel.Timestamp[i], 
                       pos_x = x_pos, pos_y = y_pos, power = Radiation)

    net = apply(field_graph, Query(ShadeNet.Net))
    rad_net = power(net[1].material)[1]/(Net_length*Net_width)
    n_df = DataFrame(Timestamp = DataForModel.Timestamp[i], power = rad_net)
                    
    out_df = vcat(out_df, i_df)
    net_df = vcat(net_df, n_df)
end

# write output for visualisation
CSV.write("output/out_day_01_100k.csv", out_df) #transparency, directlight
CSV.write("output/net_day_01_100k.csv", net_df)

