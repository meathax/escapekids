local n=0
emu.register_frame_done(function()
  n=n+1
  if n==20 then
    local sh=manager.machine.memory.shares[":palette"]
    local f=io.open("D:/Arcade/AI/aCORES/escape kids/.mame_mcp/pal20.txt","w")
    local nz=0
    for i=0,4095 do local v=sh:read_u8(i); if v~=0 then nz=nz+1 end end
    f:write("nonzero_bytes "..nz.."\n")
    -- first 64 colour words (little/big?) dump raw bytes 0..127
    local s={}
    for i=0,127 do s[#s+1]=string.format("%02X", sh:read_u8(i)) end
    f:write("pal[0:128] "..table.concat(s," ").."\n")
    -- count distinct 16-bit words
    local seen={}
    for i=0,4094,2 do local w=sh:read_u8(i)|(sh:read_u8(i+1)<<8); seen[w]=(seen[w] or 0)+1 end
    local cnt=0; for _ in pairs(seen) do cnt=cnt+1 end
    f:write("distinct_words "..cnt.."\n")
    local top={}
    for w,c in pairs(seen) do top[#top+1]={w,c} end
    table.sort(top,function(a,b) return a[2]>b[2] end)
    for i=1,math.min(8,#top) do f:write(string.format("word %04X count %d\n", top[i][1], top[i][2])) end
    f:close(); manager.machine:exit()
  end
end)
