using ProgressMeter
import DFTforge
using DFTforge.DFTrefinery
using DFTcommon
import MAT
X_VERSION = VersionNumber("0.4.0-dev+20170525");
println(" X_VERSION: ",X_VERSION)

@everywhere import DFTforge
@everywhere using DFTforge.DFTrefinery
@everywhere using DFTcommon
##############################################################################
## 1. Read INPUT
## 1.1 Set Default values
## 1.2 Read input from argument & TOML file
## 1.3 Set values from intput (arg_input)
## 1.4 Set caluations type and ouput folder
##############################################################################

hdftmpdir = ""
## 1.1 Set Default values
#orbital_mask1 = Array{Int64,1}();
#orbital_mask2 = Array{Int64,1}();
orbital_mask1_list = Array{Array{Int}}(0);
orbital_mask1_names = Array{AbstractString}(0);
orbital_mask2_list = Array{Array{Int}}(0);
orbital_mask2_names = Array{AbstractString}(0);

orbital_mask_option = DFTcommon.nomask;
orbital_mask_on = false;

k_point_num = [3,3,3]
q_point_num = [3,3,3]
ChemP_delta_ev = 0.0
DFT_type = DFTcommon.OpenMX

## 1.2 Read input from argument & TOML file
arg_input = DFTcommon.Arg_Inputs();
arg_input = parse_input(ARGS,arg_input)
#arg_input.TOMLinput = "nio_J_wannier.toml" # Debug
#arg_input.TOMLinput = "nio_J_openmx.toml" # Debug
arg_input = parse_TOML(arg_input.TOMLinput,arg_input)
# let argument override
arg_input = parse_input(ARGS,arg_input)

## 1.3 Set values from intput (arg_input)
DFT_type = arg_input.DFT_type
Wannier90_type = arg_input.Wannier90_type
spin_type = arg_input.spin_type

result_file = arg_input.result_file
ChemP_delta_ev = arg_input.ChemP_delta_ev
 # k,q point num
k_point_num = arg_input.k_point_num
q_point_num = arg_input.q_point_num
 # atom 12
atom1 = arg_input.atom1;
atom2 = arg_input.atom2;
atom12_list = arg_input.atom12_list;
hdftmpdir = arg_input.hdftmpdir;

# orbital mask
orbital_mask_option = arg_input.orbital_mask_option;

orbital_mask1_list = arg_input.orbital_mask1_list;
orbital_mask1_names = arg_input.orbital_mask1_names;
orbital_mask2_list = arg_input.orbital_mask2_list;
orbital_mask2_names = arg_input.orbital_mask2_names;
println(orbital_mask2_list," ",orbital_mask2_names)
assert(length(orbital_mask1_list) == length(orbital_mask1_names));
assert(length(orbital_mask2_list) == length(orbital_mask2_names));
if ((DFTcommon.unmask == orbital_mask_option) || (DFTcommon.mask == orbital_mask_option) )
 #orbital_mask_name = arg_input.orbital_mask_name
 orbital_mask_on = true
end

# orbital orbital_reassign
basisTransform_rule = basisTransform_rule_type()
if haskey(arg_input.Optional,"basisTransform")
  basisTransform_rule = arg_input.Optional["basisTransform"]
end

println(DFTcommon.bar_string) # print ====...====
println(atom12_list)
println("q_point_num ",q_point_num, "\tk_point_num ",k_point_num)
println(string("DFT_type ",DFT_type))
println(string("orbital_mask_option ",orbital_mask_option))
println("mask1list ",orbital_mask1_list,"\tmask2list ",orbital_mask2_list)
println("basisTransform", basisTransform_rule)

## 1.4 Set caluations type and ouput folder
cal_type = "jq.spin.test" # xq, ...

if (DFTcommon.Wannier90 == DFT_type)
  cal_type = string(cal_type,".wannier")
end
root_dir = dirname(result_file)
result_file_only = splitext(basename(result_file))
cal_name = result_file_only[1];
jq_output_dir =  joinpath(root_dir,string(cal_type,"_" ,ChemP_delta_ev))
if (!isdir(jq_output_dir))
  mkdir(jq_output_dir)
end
if ("" == hdftmpdir || !isdir(hdftmpdir) )
  hdftmpdir = jq_output_dir
end
hdf_cache_name = joinpath(hdftmpdir,string(cal_name,".hdf5"))
println(hdf_cache_name)
println(DFTcommon.bar_string) # print ====...====
##############################################################################
## 2. Calculate & Store k,q points information
## 2.1 Set Input info
## 2.2 Generate k,q points
## 2.3 Calculate Eigenstate & Store Eigenstate into file in HDF5 format
## 2.4 Send Eigenstate info to child processes
##############################################################################

## 2.1 Set Input info
hamiltonian_info = [];
if (DFTcommon.OpenMX == DFT_type)
  hamiltonian_info = set_current_dftdataset(result_file, DFTcommon.OpenMX, spin_type,basisTransform_rule)
elseif (DFTcommon.Wannier90 == DFT_type)
  atomnum = arg_input.Wannier_Optional_Info.atomnum
  atompos = arg_input.Wannier_Optional_Info.atompos
  atoms_orbitals_list = arg_input.Wannier_Optional_Info.atoms_orbitals_list

  #hamiltonian_info = DFTforge.read_dftresult(result_file,DFT_type,Wannier90_type,atoms_orbitals_list,atomnum,atompos,basisTransform_rule)
  hamiltonian_info = set_current_dftdataset(result_file,DFT_type,Wannier90_type,spin_type,atoms_orbitals_list,atomnum,atompos,basisTransform_rule)
  #hamiltonian_info = set_current_dftdataset(scf_r, DFT_type, spin_type,basisTransform_rule)
end

DFTforge.pwork(set_current_dftdataset,(hamiltonian_info, 1));

## 2.2 Generate k,q points
k_point_list = kPoint_gen_GammaCenter(k_point_num);
q_point_list = kPoint_gen_GammaCenter(q_point_num);

#k_point_list = kPoint_gen_EquallySpaced(k_point_num);
#q_point_list = kPoint_gen_EquallySpaced(q_point_num);

(kq_point_list,kq_point_int_list) = q_k_unique_points(q_point_list,k_point_list)
println(string(" kq_point_list ",length(kq_point_list)))
println(string(" q point ",length(q_point_list) ," k point ",length(k_point_list)))

## 2.3 Calculate Eigenstate & Store Eigenstate into file in HDF5 format
eigenstate_cache = cachecal_all_Qpoint_eigenstats(kq_point_list,hdf_cache_name);
gc();

## 2.4 Send Eigenstate info to child processes
DFTforge.pwork(cacheset,eigenstate_cache)
tic();
DFTforge.pwork(cacheread_lampup,kq_point_list)
toc();
################################################################################

##############################################################################
## 3. Setup extra infos (orbital, chemp shift)
##############################################################################
@everywhere function init_orbital_mask(orbital_mask_input::orbital_mask_input_Type)
    global orbital_mask1,orbital_mask2,orbital_mask_on
    orbital_mask1 = Array{Int64,1}();
    orbital_mask2 = Array{Int64,1}();
    if (orbital_mask_input.orbital_mask_on)
        orbital_mask1 = orbital_mask_input.orbital_mask1;
        orbital_mask2 = orbital_mask_input.orbital_mask2;
        orbital_mask_on = true;
    else
        orbital_mask_on = false;
    end
    #println(orbital_mask1)
end
@everywhere function init_variables(Input_ChemP_delta_ev)
  global ChemP_delta_ev
  ChemP_delta_ev = Input_ChemP_delta_ev;
end


##############################################################################
## Physical properties calculation define section
## 4. Magnetic exchange function define
## 4.1 Do K,Q sum
## 4.2 reduce K,Q to Q space
##############################################################################
## %%
## 4. Magnetic exchange function define
@everywhere function Magnetic_Exchange_J_colinear(input::Job_input_kq_atom_list_Type)
  global orbital_mask1,orbital_mask2,orbital_mask_on
  global ChemP_delta_ev
  #global SmallHks;
  ############################################################################
  ## Accessing Data Start
  ############################################################################
  # Common input info
  k_point::DFTforge.k_point_Tuple =  input.k_point
  kq_point::DFTforge.k_point_Tuple =  input.kq_point
  spin_type::DFTforge.SPINtype = input.spin_type;

  atom12_list::Vector{Tuple{Int64,Int64}} = input.atom12_list;
  result_mat = zeros(Complex_my,5,length(atom12_list))
  #atom1::Int = input.atom1;
  #atom2::Int = input.atom2;

  result_index::Int = input.result_index;
  cache_index::Int = input.cache_index;

  # Get Chemp, E_temp
  TotalOrbitalNum = cacheread(cache_index).TotalOrbitalNum;
  TotalOrbitalNum2 = TotalOrbitalNum;
  if (DFTcommon.non_colinear_type == spin_type)
    TotalOrbitalNum2 = 2*TotalOrbitalNum;
  end

  ChemP = get_dftdataset(result_index).scf_r.ChemP + ChemP_delta_ev;
  E_temp = get_dftdataset(result_index).scf_r.E_Temp;

  # Get EigenState
  eigenstate_k_up::Kpoint_eigenstate_only  = cacheread_eigenstate(k_point,1,cache_index)
  eigenstate_kq_up::Kpoint_eigenstate_only = cacheread_eigenstate(kq_point,1,cache_index)
  eigenstate_k_down::Kpoint_eigenstate_only  = cacheread_eigenstate(k_point,2,cache_index)
  eigenstate_kq_down::Kpoint_eigenstate_only = cacheread_eigenstate(kq_point,2,cache_index)

  # Get Hamiltonian
  #Hks_kq_up::Hamiltonian_type  = cacheread_Hamiltonian((0.0,0.0,0.0),1,cache_index)
  #Hks_k_down::Hamiltonian_type = cacheread_Hamiltonian((0.0,0.0,0.0),2,cache_index)

  Hks_G_up::Hamiltonian_type  = cacheread_Hamiltonian((0.0,0.0,0.0),1,cache_index)
  #Hks_G_up::Hamiltonian_type  = cacheread_Hamiltonian((0.0,0.0,0.0),1,cache_index)
  Hks_G_down::Hamiltonian_type = cacheread_Hamiltonian((0.0,0.0,0.0),2,cache_index)
  #Hks_G_down::Hamiltonian_type = cacheread_Hamiltonian((0.0,0.0,0.0),2,cache_index)

  q_point = (kq_point[1]-k_point[1],kq_point[2]-k_point[2],kq_point[3]-k_point[3])
  q_n_point = (-kq_point[1]+k_point[1],-kq_point[2]+k_point[2],-kq_point[3]+k_point[3])

  Hks_q_up::Hamiltonian_type  = cacheread_Hamiltonian(q_point,1,cache_index)
  Hks_q_down::Hamiltonian_type = cacheread_Hamiltonian(q_point,2,cache_index)

  Hks_q_n_up::Hamiltonian_type  = cacheread_Hamiltonian(q_n_point,1,cache_index)
  Hks_q_n_down::Hamiltonian_type = cacheread_Hamiltonian(q_n_point,2,cache_index)

# #=
  Hks_k_up::Hamiltonian_type  = cacheread_Hamiltonian(k_point,1,cache_index)
  Hks_kq_up::Hamiltonian_type  = cacheread_Hamiltonian(kq_point,1,cache_index)
  Hks_k_down::Hamiltonian_type = cacheread_Hamiltonian(k_point,2,cache_index)
  Hks_kq_down::Hamiltonian_type = cacheread_Hamiltonian(kq_point,2,cache_index)
# =#
  (orbitalStartIdx_list,orbitalNums) = cacheread_atomsOrbital_lists(cache_index)

  En_k_up::Array{Float_my,1} = eigenstate_k_up.Eigenvalues;
  Em_kq_up::Array{Float_my,1} = eigenstate_kq_up.Eigenvalues;
  En_k_down::Array{Float_my,1} = eigenstate_k_down.Eigenvalues;
  Em_kq_down::Array{Float_my,1} = eigenstate_kq_down.Eigenvalues;

  Es_n_k_up::Array{Complex_my,2} = eigenstate_k_up.Eigenstate;
  Es_m_kq_up::Array{Complex_my,2} = eigenstate_kq_up.Eigenstate;
  Es_n_k_down::Array{Complex_my,2} = eigenstate_k_down.Eigenstate;
  Es_m_kq_down::Array{Complex_my,2} = eigenstate_kq_down.Eigenstate;

  for (atom12_i,atom12) in enumerate(atom12_list)
    atom1 = atom12[1]
    atom2 = atom12[2]

    atom1_orbitals = orbitalStartIdx_list[atom1]+(1:orbitalNums[atom1]);
    atom2_orbitals = orbitalStartIdx_list[atom2]+(1:orbitalNums[atom2]);
    ############################################################################
    ## Accessing Data End
    ############################################################################

    # mask oribtals
    Es_n_k_up_atom1 = copy(Es_n_k_up);
    Es_n_k_up_atom2 = copy(Es_n_k_up);

    Es_n_k_down_atom1 = copy(Es_n_k_down);
    Es_n_k_down_atom2 = copy(Es_n_k_down);

    Es_m_kq_up_atom1  = copy(Es_m_kq_up);
    Es_m_kq_up_atom2  = copy(Es_m_kq_up);

    Es_m_kq_down_atom1 = copy(Es_m_kq_down);
    Es_m_kq_down_atom2 = copy(Es_m_kq_down);
    if (length(orbital_mask1)>0)
      orbital_mask1_tmp = collect(1:orbitalNums[atom1]);
      for orbit1 in orbital_mask1
          deleteat!(orbital_mask1_tmp, find(orbital_mask1_tmp.==orbit1))
      end
      Es_n_k_up_atom1[orbitalStartIdx_list[atom1]+orbital_mask1_tmp,:] = 0.0;
      Es_n_k_down_atom1[orbitalStartIdx_list[atom1]+orbital_mask1_tmp,:] = 0.0;
    end
    if (length(orbital_mask2)>0)
      orbital_mask2_tmp = collect(1:orbitalNums[atom2]);
      for orbit2 in orbital_mask2
          deleteat!(orbital_mask2_tmp, find(orbital_mask2_tmp.==orbit2))
      end
      Es_m_kq_up_atom2[orbitalStartIdx_list[atom2]+orbital_mask2_tmp,:]   = 0.0;
      Es_m_kq_down_atom2[orbitalStartIdx_list[atom2]+orbital_mask2_tmp,:]   = 0.0;
    end

    ## Do auctual calucations
    Fftn_k_up  = 1.0./(exp( ((En_k_up)  - ChemP)/(kBeV*E_temp)) + 1.0 );
    Fftm_kq_up = 1.0./(exp( ((Em_kq_up) - ChemP)/(kBeV*E_temp)) + 1.0 );


    Fftn_k_down  = 1.0./(exp( ((En_k_down)  - ChemP)/(kBeV*E_temp)) + 1.0 );
    Fftm_kq_down = 1.0./(exp( ((Em_kq_down) - ChemP)/(kBeV*E_temp)) + 1.0 );

    dFnk_down_Fmkq_up =
      Fftn_k_down*ones(1,TotalOrbitalNum2)  - ones(TotalOrbitalNum2,1)*Fftm_kq_up[:]' ;
    dFnk_up_Fmkq_down =
      Fftn_k_up*ones(1,TotalOrbitalNum2)  - ones(TotalOrbitalNum2,1)*Fftm_kq_down[:]' ;


    Enk_down_Emkq_up =
      En_k_down[:]*ones(1,TotalOrbitalNum2) - ones(TotalOrbitalNum2,1)*Em_kq_up[:]' ;
    Enk_up_Emkq_down =
      En_k_up[:]*ones(1,TotalOrbitalNum2) - ones(TotalOrbitalNum2,1)*Em_kq_down[:]' ;
    #Enk_Emkq += im*0.001;

#=
    V1_down_up = Hks_kq_up[atom1_orbitals,atom1_orbitals] - Hks_k_down[atom1_orbitals,atom1_orbitals];
    V2_up_down = Hks_k_down[atom2_orbitals,atom2_orbitals] - Hks_kq_up[atom2_orbitals,atom2_orbitals];

    V1_down_up *= 0.5;
    V2_up_down *= 0.5;

    V1_up_down   = Hks_kq_down[atom1_orbitals,atom1_orbitals] - Hks_k_up[atom1_orbitals,atom1_orbitals];
    V2_down_up = Hks_k_up[atom2_orbitals,atom2_orbitals] - Hks_kq_down[atom2_orbitals,atom2_orbitals];

    V1_up_down *= 0.5;
    V2_down_up *= 0.5;
=#
    V1_G = Hks_G_up[atom1_orbitals,atom1_orbitals] - Hks_G_down[atom1_orbitals,atom1_orbitals];
    V2_G = Hks_G_up[atom2_orbitals,atom2_orbitals] - Hks_G_down[atom2_orbitals,atom2_orbitals];
    V1_G *= 0.5;
    V2_G *= 0.5;

    V1_q = 0.5*(Hks_q_up[atom1_orbitals,atom1_orbitals]-Hks_q_down[atom1_orbitals,atom1_orbitals])
    V2_q = 0.5*(Hks_q_up[atom2_orbitals,atom2_orbitals]-Hks_q_down[atom2_orbitals,atom2_orbitals])

    V1_q_n = 0.5*(Hks_q_n_up[atom1_orbitals,atom1_orbitals]-Hks_q_n_down[atom1_orbitals,atom1_orbitals])
    V2_q_n = 0.5*(Hks_q_n_up[atom2_orbitals,atom2_orbitals]-Hks_q_n_down[atom2_orbitals,atom2_orbitals])


    V1_k = 0.5*(Hks_k_up[atom1_orbitals,atom1_orbitals] - Hks_k_down[atom1_orbitals,atom1_orbitals]);
    V2_kq = 0.5*(Hks_kq_up[atom2_orbitals,atom2_orbitals] - Hks_kq_down[atom2_orbitals,atom2_orbitals]);

    V1_kq = 0.5*(Hks_kq_up[atom1_orbitals,atom1_orbitals] - Hks_kq_down[atom1_orbitals,atom1_orbitals]);
    V2_k = 0.5*(Hks_k_up[atom2_orbitals,atom2_orbitals] - Hks_k_down[atom2_orbitals,atom2_orbitals]);

    V1_kq_k = 0.5*(Hks_kq_up[atom1_orbitals,atom1_orbitals] - Hks_k_down[atom1_orbitals,atom1_orbitals]);
    V2_kq_k = 0.5*(Hks_kq_up[atom2_orbitals,atom2_orbitals] - Hks_k_down[atom2_orbitals,atom2_orbitals]);
    #atom1_orbitals_rel = 1:orbitalNums[atom1];
    #atom2_orbitals_rel = 1:orbitalNums[atom2];
    #atom2_orbitals_rel2 = orbitalNums[atom1]+atom2_orbitals_rel;

    VV1_down_up_G = Es_n_k_down_atom1[atom1_orbitals,:]' * V1_G *
            Es_m_kq_up_atom1[atom1_orbitals,:];
    VV2_up_down_G = Es_m_kq_up_atom2[atom2_orbitals,:]' * V2_G *
        Es_n_k_down_atom2[atom2_orbitals,:];


    VV1_down_up = Es_n_k_down_atom1[atom1_orbitals,:]' * V1_q *
            Es_m_kq_up_atom1[atom1_orbitals,:];
    VV2_up_down = Es_m_kq_up_atom2[atom2_orbitals,:]' * V2_q_n*
        Es_n_k_down_atom2[atom2_orbitals,:];

    VV1_up_down = Es_n_k_up_atom1[atom1_orbitals,:]' * V1_kq *
            Es_m_kq_down_atom1[atom1_orbitals,:];
    VV2_down_up = Es_m_kq_down_atom2[atom2_orbitals,:]' * V2_k *
        Es_n_k_up_atom2[atom2_orbitals,:];

    Vi_Vj_down_up_up_down_G = transpose(VV1_down_up_G).*VV2_up_down_G;
    Vi_Vj_down_up_up_down = transpose(VV1_down_up).*VV2_up_down;
    Vi_Vj_up_down_down_up = transpose(VV1_up_down).*VV2_down_up;

    # for testing
    VV1_down_up2 = Es_n_k_down_atom1[atom1_orbitals,:]' * V1_k *
            Es_m_kq_up_atom1[atom1_orbitals,:];
    VV2_up_down2 = Es_m_kq_up_atom2[atom2_orbitals,:]' * V2_kq *
        Es_n_k_down_atom2[atom2_orbitals,:];

    VV1_up_down2 = Es_n_k_up_atom1[atom1_orbitals,:]' * V1_k *
            Es_m_kq_down_atom1[atom1_orbitals,:];
    VV2_down_up2 = Es_m_kq_down_atom2[atom2_orbitals,:]' * V2_kq *
        Es_n_k_up_atom2[atom2_orbitals,:];

    Vi_Vj_down_up_up_down2 = transpose(VV1_down_up2).*VV2_up_down2;
    Vi_Vj_up_down_down_up2 = transpose(VV1_up_down2).*VV2_down_up2;

    J_ij_G =  0.5./(-Enk_down_Emkq_up).*dFnk_down_Fmkq_up .* Vi_Vj_down_up_up_down_G ;
    J_ij_2 =  0.5./(-Enk_down_Emkq_up).*dFnk_down_Fmkq_up .* Vi_Vj_down_up_up_down ;
    J_ij_3 =  0.5./(-Enk_up_Emkq_down).*dFnk_up_Fmkq_down .* Vi_Vj_up_down_down_up ;

    J_ij_4 =  0.5./(-Enk_down_Emkq_up).*dFnk_down_Fmkq_up .* Vi_Vj_down_up_up_down2 ;
    J_ij_5 =  0.5./(-Enk_up_Emkq_down).*dFnk_up_Fmkq_down .* Vi_Vj_up_down_down_up2 ;

    #return sum(J_ij[:])*Hartree2cm;
    #return sum(J_ij[!isnan(J_ij)] )*Hartree2cm;

    result_mat[1,atom12_i] = sum(J_ij_G[!isnan(J_ij_G)] );
    #result_mat[2,atom12_i] = sum(J_ij_1[!isnan(J_ij_1)] ) + sum(J_ij_2[!isnan(J_ij_2)] );
    result_mat[2,atom12_i] = sum(J_ij_2[!isnan(J_ij_2)] );
    result_mat[3,atom12_i] = sum(J_ij_3[!isnan(J_ij_3)] );
    result_mat[4,atom12_i] = sum(J_ij_4[!isnan(J_ij_4)] );
    result_mat[5,atom12_i] = sum(J_ij_5[!isnan(J_ij_5)] );
  end
  return result_mat

end


num_return = 5;

## 4.1 Do K,Q sum
# for orbital_mask1_list,orbital_mask2_list combinations

for (orbital1_i,orbital_mask1) in enumerate(orbital_mask1_list)
  for (orbital2_i,orbital_mask2) in enumerate(orbital_mask2_list)
    orbital_mask_input = orbital_mask_input_Type(orbital_mask1,orbital_mask2,(-1,-1),false)
    if (orbital_mask_on)
        orbital_mask_input = orbital_mask_input_Type(orbital_mask1,orbital_mask2,(-1,-1),true)
    end
    orbital_mask_name = orbital_mask1_names[orbital1_i]*"_"*orbital_mask2_names[orbital2_i];
    println(DFTcommon.bar_string) # print ====...====
    println(orbital_mask_name," mask1 ",orbital_mask1,"\tmask2 ",orbital_mask2)

    # setup extra info
    DFTforge.pwork(init_orbital_mask,orbital_mask_input)
    DFTforge.pwork(init_variables,ChemP_delta_ev)

    (X_Q_nc,X_Q_mean_nc) = Qspace_Ksum_atomlist_parallel(Magnetic_Exchange_J_colinear,
    q_point_list,k_point_list,atom12_list,num_return)
    #println(typeof(X_Q_mean_nc))
    println(DFTcommon.bar_string) # print ====...====
    ## 4.2 reduce K,Q to Q space
    # Average X_Q results
    Xij_Q_mean_matlab = Array(Array{Complex_my,1},num_return,length(atom12_list));
    for (atom12_i,atom12) in enumerate(atom12_list)
      atom1 = atom12[1];
      atom2 = atom12[2];
      for xyz_i = 1:num_return
        Xij_Q_mean_matlab[xyz_i,atom12_i] = zeros(Complex_my,length(q_point_list));
        for (q_i,q_point) in enumerate(q_point_list)
          q_point_int = k_point_float2int(q_point);
          Xij_Q_mean_matlab[xyz_i,atom12_i][q_i] =
            X_Q_mean_nc[xyz_i,atom12_i][q_point_int];
        end
        println(string(" Gamma point J [",atom1,",",atom2,"] ",xyz_i," :",
          1000.0*mean(Xij_Q_mean_matlab[xyz_i,atom12_i][:])," meV"))
      end
    end
    ###############################################################################
    ## 5. Save results and clear hdf5 file
    ## 5.1 Prepaire infomations for outout
    ## 5.2 Write to MAT
    ###############################################################################
    optionalOutputDict = Dict{AbstractString,Any}()
    optionalOutputDict["num_return"] = num_return;
    optionalOutputDict["VERSION_Spin_Exchange"] = string(X_VERSION);

    export2mat_K_Q(Xij_Q_mean_matlab,hamiltonian_info,q_point_list,k_point_list,atom12_list,
    orbital_mask_on,orbital_mask1,orbital_mask2,ChemP_delta_ev,
    optionalOutputDict,
    jq_output_dir,cal_name,
    orbital_mask_name,cal_type);
  end
end

## 5.3 Cleanup HDF5 cache file
println(DFTcommon.bar_string) # print ====...====
println("hdf_cache_name:",hdf_cache_name)
if (isfile(hdf_cache_name))
  rm(hdf_cache_name)
  file = open(hdf_cache_name,"w");
  close(file);
end
