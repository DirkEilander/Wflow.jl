tomlpath = joinpath(@__DIR__, "sbm_config.toml")
config = Wflow.Config(tomlpath)

model = Wflow.initialize_sbm_model(config)

@unpack network = model

min_sto = get(config.model, "min_streamorder", 4)
index_pit = [network.land.order[end]]
@test min_sto == 3

subbas_order, indices_subbas, topo_subbas =
    Wflow.kinwave_set_subdomains(config, network.land.graph, network.land.order, index_pit)

Wflow.close_files(model, delete_output = false)

if nthreads() == 1
    @testset "Nonparallel subdomains kinematic wave (nthreads = 1)" begin
        @test subbas_order == [[1]]
        @test indices_subbas == [[1:length(network.land.order);]]
        @test topo_subbas == [network.land.order]
    end
else
    @testset "Parallel subdomains kinematic wave (nthreads > 1)" begin
        @test length(subbas_order) == 6
        @test length.(subbas_order) == [507, 172, 142, 86, 24, 1]
        @test maximum(subbas_order) == [932]
        @test subbas_order[1][1:4] == [107, 115, 83, 84]
        @test subbas_order[3][1:4] == [97, 109, 56, 68]
        @test length(topo_subbas) == 932
        @test topo_subbas[1][1:4] == [50062, 50063, 50056, 50055]
        @test topo_subbas[end][1:4] == [49884, 49842, 49791, 49779]
        @test length(indices_subbas) == 932
        @test indices_subbas[1][1:4] == [1, 2, 8, 9]
        @test indices_subbas[end][1:4] == [166, 201, 236, 247]
    end
end

@testset "Streamorder and subbasins" begin
    # directed acyclic graph of basin
    g = DiGraph(16)
    add_edge!(g, 1, 3)
    add_edge!(g, 2, 3)
    add_edge!(g, 3, 4)
    add_edge!(g, 4, 5)
    add_edge!(g, 5, 6)
    add_edge!(g, 7, 9)
    add_edge!(g, 8, 9)
    add_edge!(g, 9, 4)
    add_edge!(g, 10, 12)
    add_edge!(g, 11, 12)
    add_edge!(g, 12, 16)
    add_edge!(g, 13, 15)
    add_edge!(g, 14, 15)
    add_edge!(g, 15, 16)
    add_edge!(g, 16, 5)

    # generate streamorder and subbasins (ids, graph and order)
    toposort = topological_sort_by_dfs(g)
    strord = Wflow.stream_order(g, toposort)
    subbas = Wflow.subbasins(g, strord, toposort, 2)
    subbas_fill = Wflow.fillnodata_upstream(g, toposort, subbas, 0)
    graph_subbas = Wflow.graph_from_nodes(g, subbas, subbas_fill)
    toposort_subbas = topological_sort_by_dfs(graph_subbas)
    dist =
        Graphs.Experimental.Traversals.distances(Graph(graph_subbas), toposort_subbas[end])
    max_dist = maximum([dist; 1])
    subbas_order = Wflow.subbasins_order(graph_subbas, toposort_subbas[end], max_dist)

    @test strord == [1, 1, 2, 3, 4, 4, 1, 1, 2, 1, 1, 2, 1, 1, 2, 3]
    @test strord[toposort[end]] == 4
    @test subbas == [0, 0, 5, 6, 0, 7, 0, 0, 4, 0, 0, 2, 0, 0, 1, 3]
    @test subbas_fill == [5, 5, 5, 6, 7, 7, 4, 4, 4, 2, 2, 2, 1, 1, 1, 3]
    @test toposort_subbas == [5, 4, 6, 2, 1, 3, 7]
    @test max_dist == 2
    @test subbas_order == [[1, 2, 4, 5], [3, 6], [7]]
end
