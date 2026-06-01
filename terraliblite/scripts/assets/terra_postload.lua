
-- create list of all material IDs mapped to names
local mats = assets.byExtension("material")
local templates = {}
local matids = {}
for k,v in next, mats do
  local mat = assets.json(v)
  matids[mat.materialId] = mat.materialName
  if mat.renderTemplate and not templates[mat.renderTemplate] then
    templates[mat.renderTemplate] = true
  end
end
assets.add("/scripts/assets/terra_matIds.json", matids)
local structures = assets.json("/terra_structures.config")
structures.allBlockTemplates = jarray()
for k,v in next, templates do
  table.insert(structures.allBlockTemplates,k)
end
assets.erase("/terra_structures.config")
assets.add("/terra_structures.config", structures)
