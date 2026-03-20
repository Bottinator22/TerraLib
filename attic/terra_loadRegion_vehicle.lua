require "/scripts/rect.lua"
-- designed to be used like world.loadRegion, works on both client and server master

function loadRegion(r)
    if world.loadRegion then
        return world.loadRegion(r)
    else
        local poly = {
            {r[1],r[2]},{r[1],r[4]},{r[3],r[4]},{r[3],r[2]}
        }
        local loader = world.entityQuery(poly[1],poly[3],{includedTypes={"vehicle"},boundMode="metaboundbox",callScript="sd_isLoaderOf",callScriptArgs={r}})[1]
        if not loader then
            local c = rect.center(r)
            local relRect = rect.withCenter({0,0},rect.size(r))
            local params = root.assetJson("/scripts/terra_loaderParams.json")
            params.boundBox = rect.pad(relRect,10)
            params.region = relRect
            world.spawnVehicle("compositerailplatform", c, params)
        end
        world.debugPoly(poly,"yellow")
        return not world.polyCollision(poly,nil,{"Null"})
    end
end 
