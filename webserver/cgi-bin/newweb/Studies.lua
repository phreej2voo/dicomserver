-- first gateway for XviewWeb; 
-- note 1: will return empty .xdr link; need to change dataset.js
-- note 2: returns simplified AVS header; need to change dataset.js
-- note 3: or returns dicom slices as serialized json; need to change dataset.js
-- mvh 20220206: supports DICOM, DICOM jpeg, json for CT and dcm and json for RTSTRUCT
-- mvh 20220209: Modified names to straight SOPInstanceUID

function remotequery(level, q)
  local remotecode =
[[
  local ae=']]..servercommand('get_param:MyACRNema')..[[';
  local level=']]..level..[[';
  local q=]]..q:Serialize()..[[;
  local q2=DicomObject:new(); for k,v in pairs(q) do q2[k]=v end;
  local r = dicomquery(ae, level, q2):Serialize();
  local s=tempfile('txt') local f=io.open(s, "wb") f:write(r) returnfile=s f:close();
]]
  local g = loadstring('return '..servercommand('lua:'..remotecode));
  if g then return g() end
end

-- split string into pieces, return as table
function split(str, pat)
   local t = {} 
   local fpat = "(.-)" .. pat
   local last_end = 1
   local s, e, cap = str:find(fpat, 1)
   while s do
      if s ~= 1 or cap ~= "" then
	 table.insert(t,cap)
      end
      last_end = e+1
      s, e, cap = str:find(fpat, last_end)
   end
   if last_end <= #str then
      cap = str:sub(last_end)
      table.insert(t, cap)
   end
   return t
end

function readremote(f)
  local o=DicomObject:new()
  o["9999,0400"]="lua:x=DicomObject:newarray();y=DicomObject:new();y:Read('"..f.."');x:Add(y);Command:SetVR(0x0008,0x3001,x)"
  local r=dicomecho(servercommand('get_param:MyACRNema'), o)
  return r:GetVR(0x0008,0x3001)[0]:Copy()
end

function readremotecompressed(f)
  local o=DicomObject:new()
  o["9999,0400"]="lua:x=DicomObject:newarray();y=DicomObject:new();y:Read('"..f.."');y=y:Compress('n5');x:Add(y);Command:SetVR(0x0008,0x3001,x)"
  local r=dicomecho(servercommand('get_param:MyACRNema'), o)
  return r:GetVR(0x0008,0x3001)[0]:Copy()
end

--function readremoteseries(f)
--  local o=DicomObject:new()
--  o.SeriesInstanceUID=f;
--  o.QueryRetrieveLevel='SERIES';
--  o=dicomget(servercommand('get_param:MyACRNema'),'IMAGE',o)
--  return o;
--end

local patid = string.gsub(series2, ':[^:]-$', '')
local seriesuid = string.gsub(series2, '^.*:', '')

-- locate Series to go with RTSTRUCT; cache it as well
if CGI('rtstruct')~='' then
  local f=io.open(CGI('rtstruct'), 'r')
  if f then
    patid = f:read()
    seriesuid=f:read()
    f:close()
  else
    local im = readremote(':'..CGI('rtstruct'))
    seriesuid = im.ReferencedFrameOfReferenceSequence[0].RTReferencedStudySequence[0].RTReferencedSeriesSequence[0].SeriesInstanceUID
    patid = im.PatientID
    local f=io.open(CGI('rtstruct'), 'w')
    f:write(patid..'\n')
    f:write(seriesuid..'\n')
    f:close()
  end
end

local scanName='CT/axial' -- can be CT/axial or CT/axial/full (overrules sliceFormat, uses compressed XDR)
local sliceFormat='dj2'   -- can be bmp, json, dcm, or dj2

-- output scan.json file
if string.find(CGI('path'), 'scan%.json')~=nil then
  local b=DicomObject:new();
  b.QueryRetrieveLevel='IMAGE'
  b.PatientID        = patid
  b.SeriesInstanceUID = seriesuid
  b.SOPInstanceUID   = ''
  b.SliceLocation   = ''
  local imaget=remotequery('IMAGE', b, series2)
  table.sort(imaget, function(a,b) return (tonumber(a.SliceLocation) or 0)>(tonumber(b.SliceLocation) or 0) end)
  local imagen = {}
  for k,v in ipairs(imaget) do
    --table.insert(imagen, [["]]..v.PatientID..':'..v.SOPInstanceUID..[["]])
    table.insert(imagen, [["]]..v.SOPInstanceUID..[["]])
  end
  local names = table.concat(imagen, ',')

  HTML('Content-type: application/json\n');
  
  x1 = readremote(imaget[1].PatientID..':'..imaget[1].SOPInstanceUID)
  x2 = readremote(imaget[2].PatientID..':'..imaget[2].SOPInstanceUID)
  local sliceSpacing = (x1.SliceLocation+0)/10-(x2.SliceLocation+0)/10
  io.write([[
  {"xDim":]]..x1.Rows..[[,"yDim":]]..x1.Columns..[[,"sliceDim":]]..#imaget..[[,"sliceSpacing":]]..sliceSpacing..[[
  ,"sliceStart": ]]..(x1.SliceLocation*0)/10 ..[[,"rescaleSlope":1,"rescaleOffset":0
  ,"folderName":"CT","direction":"axial","level":1000,"window":200
  ,"slice":]]..math.floor(#imaget/2)..[[,"zoom":1,"panX":0,"panY":0
  ,"sx":]]..tonumber(string.match(x1.ImagePositionPatient, "(.-)\\.*"))/-10 ..[[,"sy":]]..tonumber(string.match(x1.ImagePositionPatient, ".-\\(.-)\\.-"))/-10 ..[[,"sz":]]..tonumber(x1.SliceLocation)/10 ..[[
  ,"mx":1,"my":1,"mz":-1,"iop":"1\\0\\0\\0\\1\\0 "
  ,"sliceFormat":"]]..sliceFormat..[[","sliceNames":[ ]]..names..[[ ]
  ,"LWpresets":[{"name": "initial", "level": 1000, "window": 200}
  ,{"name": "brain", "level": 1059, "window": 40}
  ,{"name": "mediastinum", "level": 1034, "window": 210}
  ,{"name": "lung", "level": 500, "window": 750}]}
  ]]
  )
  return

-- generate list of scans (just 1)
elseif string.find(CGI('path'), 'scans.json') then
  HTML('Content-type: application/json\n');
  io.write('["'..scanName..'"]');
  return

-- generate output files; single slice as dcm
elseif string.find(CGI('path'), '/slices/')~=nil and string.find(CGI('path'), '.dcm')~=nil then
  local i=string.match(CGI('path'), ".+/(.-)%.dcm")
  if string.find(i, ':')==nil then i=':'..i end
  servercommand('convert_to_dicom:'..i..',,un', 'cgi')
  return

-- generate output files; single slice as dcm jpeg lossless
elseif string.find(CGI('path'), '/slices/')~=nil and string.find(CGI('path'), '.dj2')~=nil then
  local i=string.match(CGI('path'), ".+/(.-)%.dj2")
  if string.find(i, ':')==nil then i=':'..i end
  servercommand('convert_to_dicom:'..i..',,j2', 'cgi')
  return

-- generate output files; single slice as json
elseif string.find(CGI('path'), '/slices/')~=nil and string.find(CGI('path'), '.json')~=nil then
  HTML('Content-type: application/json\n');
  local i=string.match(CGI('path'), ".+/(.-)%.json")
  if string.find(i, ':')==nil then i=':'..i end
  local x = readremote(i)
  io.write(x:Serialize(true, true));
  return

-- generate output files; compressed slice as bmp
elseif string.find(CGI('path'), '/slices/')~=nil and string.find(CGI('path'), '.bmp')~=nil then
  local i=string.match(CGI('path'), ".+/(.-)%.bmp")
  if string.find(i, ':')==nil then i=':'..i end
  local x = readremotecompressed(i)
  HTML('Content-type: image/bmp\n');
  io.write("BM")
  io.write(string.rep(string.char(0), 52))
  io.write("#\n")
  io.write("dim1="..x.Rows..'\n')
  io.write("dim2="..x.Columns..'\n')
  io.write("nki_compression=5\n")
  io.write("pixelsize="..string.match(x.PixelSpacing, "(.-)\\.*")/10 ..'\n')
  io.write(string.char(12, 12))
  io.write(x:GetVR(0x7fdf,0x10,true))
  servercommand('lua:print("served bmp slice")')
  return

-- generate output files; reference list (empty)
elseif string.find(CGI('path'), 'references.json') then
  HTML('Content-type: application/json\n')
  io.write('[]');    
  return

-- generate output files; structure list
elseif string.find(CGI('path'), 'structures.json') then
  HTML('Content-type: application/json\n');
  if CGI('rtstruct')=='' then
    io.write('[]');    
    return
  end

  local ima = readremote(':'..CGI('rtstruct'))

  local structures={}
  local s0=ima:GetVR(0x3006,0x0020)
  local j
  for j=0, #s0-1 do
    structures[tonumber(s0[j].ROINumber or 0) or 0] = {}
    structures[tonumber(s0[j].ROINumber or 0) or 0].name = s0[j].ROIName
  end

  local s0=ima:GetVR(0x3006,0x0039)
  for j=0, #s0-1 do
    local ROI = tonumber(s0[j].ReferencedROINumber)
    if s0[j].ContourSequence and s0[j].ContourSequence[0].ContourGeometricType~='POINT' then
      structures[ROI] = structures[ROI] or {}
      local color = split(s0[j].ROIDisplayColor, '\\')
      structures[ROI].color = string.format('#%02x%02x%02x', color[1], color[2], color[3])
      structures[ROI].number = ROI -- used in DICOM RTSTRUCT reader
    else
      structures[ROI]=nil
    end
  end
  local str={}
  for k, v in pairs(structures) do
    table.insert(str, v)
  end
  io.write(require('JSON'):encode({structures=str}))
  servercommand('lua:print("served structure list")')
  return
      
-- generate output files; volume
elseif string.find(CGI('path'), '.xdr') then
  local b=DicomObject:new();
  b.QueryRetrieveLevel='IMAGE'
  b.PatientID        = patid
  b.SeriesInstanceUID = seriesuid
  b.SOPInstanceUID   = ''
  b.SliceLocation   = ''
  local imaget=remotequery('IMAGE', b, series2)
  table.sort(imaget, function(a,b) return (tonumber(a.SliceLocation) or 0)>(tonumber(b.SliceLocation) or 0) end)

  HTML('Content-type: application/raw\n');
  local x = readremotecompressed(patid..':'..imaget[1].SOPInstanceUID)
  io.write("#\n")
  io.write("dim1="..x.Rows..'\n')
  io.write("dim2="..x.Columns..'\n')
  io.write("dim3="..#imaget..'\n')
  io.write("nki_compression=5\n")
  io.write("pixelsize="..string.match(x.PixelSpacing, "(.-)\\.*")/10 ..'\n')
  io.write(string.char(12, 12))

  local s = x:GetVR(0x7fdf,0x10,true)
  local l = s:byte(9)
  if l/2==math.floor(l/2) then 
    io.write(s) 
  else
    io.write(s:sub(1, -2)) 
  end

  for i=2, #imaget do
    local x = readremotecompressed(patid..':'..imaget[i].SOPInstanceUID)
    local s = x:GetVR(0x7fdf,0x10,true)
    local l = s:byte(9)
    if l/2==math.floor(l/2) then 
      io.write(s:sub(21)) 
    else
      io.write(s:sub(21, -2)) 
    end
  end
  servercommand('lua:print("served 3D volume")')
  return

-- generate output files; rtstruct in json format (dump of DICOM object)
elseif string.find(CGI('path'), '/Delineations/')~=nil and CGI('rtstruct')~='' and string.find(CGI('path'), '.json')~=nil then
  ima = readremote(':'..CGI('rtstruct'))
  --ima = DicomObject:new()
  --ima:Read(CGI('rtstruct')..'.dcm')
  HTML('Content-type: application/json\n')
  io.write(ima:Serialize(true))
  return

-- generate output files; rtstruct as dcm
elseif string.find(CGI('path'), '/Delineations/')~=nil and CGI('rtstruct')~='' and string.find(CGI('path'), '.dcm')~=nil then
  local i=string.match(CGI('path'), ".+/(.-)%.dcm")
  servercommand('convert_to_dicom::'..CGI('rtstruct'), 'cgi')
  return  

-- incorrect request
else
  HTML('Content-type: application/json\n')
  io.write('{"Incorrect_request":1}');    
  return
end
