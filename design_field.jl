
#----------------------------------------------#
# Create a module shadenet with two node types #
#----------------------------------------------#
module ShadeNet
    using VirtualPlantLab
    axiom_field = (RH(Main.Net_orientation))
    Base.@kwdef struct Net <: VirtualPlantLab.Node 
        length::Float64 = Main.Net_length
        width::Float64 = Main.Net_width
        material::Lambertian{1} = Lambertian(τ = Main.Net_transparency, ρ = 0.0)
    end

    Base.@kwdef struct Pole <: VirtualPlantLab.Node 
        height::Float64 = Main.Net_height
        width::Float64 = 0.1
        material::Lambertian{1} = Lambertian(τ = 0.0, ρ = 0.1)
    end

    Base.@kwdef mutable struct Tile <: VirtualPlantLab.Node
        length::Float64 = Main.Soil_resolution
        material::Black = Black(1)
        light::Float64 = 0.0
        pos_x::Float64 = 0.0
        pos_y::Float64 = 0.0
    end
end

import .ShadeNet

#------------------------------------------------------------------------#
# Create the turtle geometries that are passed when the graph is created #
# Via the feed! function: NEEDS the `vars` keyword                       #
#------------------------------------------------------------------------#


function VirtualPlantLab.feed!(turtle::Turtle, n::ShadeNet.Net, vars)
    ra!(turtle, 90.0)
    ru!(turtle, -90.0)
    Rectangle!(turtle, length = n.length, width = n.width, move = false, 
               color = RGBA(0.0,1.0,0.2, 0.5), material = n.material)
    ru!(turtle, 90.0)
    ra!(turtle, -90.0)
    return nothing
end

function VirtualPlantLab.feed!(turtle::Turtle, p::ShadeNet.Pole, vars)
    SolidCube!(turtle, length = p.height, width = p.width, height = p.width, move = false,
               color = RGB(0.0,0.0,0.2), material = p.material)
    return nothing
end

function VirtualPlantLab.feed!(turtle::Turtle, t::ShadeNet.Tile, vars)
    ra!(turtle, 90.0)
    Rectangle!(turtle, length = t.length, move = true, 
               color = RGB(1.0,1.0,0.2), material = t.material)
    ra!(turtle, -90.0)
    return nothing
end

#---------------------------------------#
# Design axiom for net and soil objects #
#---------------------------------------#
#tiles_x = cos(Main.Net_orientation*(-pi/180))*(-(Net_length/2):Soil_resolution:(Net_length/2)) - sin(Main.Net_orientation*(-pi/180))*(-(Field_width/2):Soil_resolution:(Field_width/2))
#tiles_y = sin(Main.Net_orientation*(-pi/180))*(-(Net_length/2):Soil_resolution:(Net_length/2)) - cos(Main.Net_orientation*(-pi/180))*(-(Field_width/2):Soil_resolution:(Field_width/2))
#n_poles = length(-(Net_length/2):Pole_distance:(Net_length/2))
#poles_x = (-(Net_length/2):Pole_distance:(Net_length/2))*cos(Main.Net_orientation*(-pi/180)) - sin(Main.Net_orientation*(-pi/180))*repeat([0.0],n_poles)
#poles_y = (-(Net_length/2):Pole_distance:(Net_length/2))*sin(Main.Net_orientation*(-pi/180)) + cos(Main.Net_orientation*(-pi/180))*repeat([0.0],n_poles)

# Tile position and rotation
tiles_x = -(Field_width/2):Soil_resolution:(Field_width/2)
tiles_y = -(Field_length/2):Soil_resolution:(Field_length/2)
tiles_z = zeros(length(tiles_y))
tile_positions = [VirtualPlantLab.Vec(i,j,0) for i = tiles_x, j = tiles_y]
get_R_mat(t) = [cos(t) -sin(t) 0; sin(t) cos(t) 0; 0 0 1]
R = get_R_mat(Main.Net_orientation * (pi/180))

xs = [t[1] for t in tile_positions] |> x -> reduce(vcat, x)
ys = [t[2] for t in tile_positions] |> x -> reduce(vcat, x)
zs =[t[3] for t in tile_positions] |> x -> reduce(vcat, x)
coords = [xs'; ys'; zs']
rot_coords = R * coords |> x -> reshape(x, (3, length(tiles_x), length(tiles_y)))
tile_positions_rot = [VirtualPlantLab.Vec(rot_coords[:, x, y]...) for x in 1:size(rot_coords)[2], y in 1:size(rot_coords)[3]]

# Pole position and rotation
poles_y = -(Net_length/2):Pole_distance:(Net_length/2)
pole_positions = [VirtualPlantLab.Vec(0, i, 0) for i = poles_y ]

xs_p = [p[1] for p in pole_positions] |> x -> reduce(vcat, x)
ys_p = [p[2] for p in pole_positions] |> x -> reduce(vcat, x)
zs_p =[p[3] for p in pole_positions] |> x -> reduce(vcat, x)
coords_p = [xs_p'; ys_p'; zs_p']
rot_coords_p = R * coords_p |> x -> reshape(x, (3, length(poles_y)))
pole_positions_rot = [VirtualPlantLab.Vec(rot_coords_p[:, x]...) for x in 1:size(rot_coords_p)[2]]

# Net position and rotation
xs_n = 0.0 #Net_length/2 + 4.0
ys_n = Net_length/2
zs_n = Net_height
coords_n = [xs_n'; ys_n'; zs_n']
rot_coords_n = R * coords_n 
net_position_rot = VirtualPlantLab.Vec(rot_coords_n...)


for pos_t in tile_positions_rot
    ShadeNet.axiom_field = ShadeNet.axiom_field + (T(pos_t) + ShadeNet.Tile(pos_x = pos_t[1], pos_y = pos_t[2]))
end
for pos in pole_positions_rot
    ShadeNet.axiom_field = ShadeNet.axiom_field + (T(pos) + ShadeNet.Pole())
end
ShadeNet.axiom_field = ShadeNet.axiom_field + (T(net_position_rot) + ShadeNet.Net())

field_graph = Graph(axiom = ShadeNet.axiom_field)
sc_total = VirtualPlantLab.Scene(field_graph)

