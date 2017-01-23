import os;
import array;
import re;

def get_file_content(filename):
    src_file = open("..\src\Shaders\\" + filename, 'r')
    return src_file.read()

def load_array(name, filename):
    src_file = open("..\src\Shaders\\" + filename)
    if filename.endswith('.vert'):
        temporary_file = open('temp.vert', 'w')
    elif filename.endswith('.frag'):
        temporary_file = open('temp.frag', 'w')
    else:
        temporary_file = open('temp.comp', 'w')
    line = src_file.readline()
    while line != '':
        m = re.search(r'^#include "(.*)"', line)
        if m:
            temporary_file.write(get_file_content(m.group(1)))
        else:
            temporary_file.write(line)
        line = src_file.readline()
    temporary_file.close()
    if filename.endswith('.vert'):
        os.system("glslangValidator.exe -V temp.vert")
        f = open("vert.spv", 'rb')
        filesize = os.path.getsize("vert.spv")
    elif filename.endswith('.frag'):
        os.system("glslangValidator.exe -V temp.frag")
        f = open("frag.spv", 'rb')
        filesize = os.path.getsize("frag.spv")
    else:
        os.system("glslangValidator.exe -V temp.comp")
        f = open("comp.spv", 'rb')
        filesize = os.path.getsize("comp.spv")
    a = array.array('L')
    a.fromfile(f, filesize // 4)
    f.close()
    code = "const std::vector<uint32_t> " + name +" = {"
    for i in a:
        code += str(i) + ",\n"
    code += "};\n"
    return code

output = open("..\src\AMD_AOFX_Precompiled.h", 'w')
output.write("#include <vector>\n")
#output.write(load_array("hair_shadow_vertex", "AMD_AOFX.glsl"))
output.write(load_array("hair_shadow_fragment", "AMD_AOFX_Common.glsl"))
#output.write(load_array("render_hair_vertex", "AMD_AOFX_Deinterleave.comp"))
#output.write(load_array("render_hair_aa_vertex", "AMD_AOFX_Kernel.glsl"))
#output.write(load_array("render_hair_strand_copies_vertex", "AMD_Deinterleave.glsl"))
#output.write(load_array("render_hair_aa_strand_copies_vertex", "AMD_Utility.glsl"))
#output.write(load_array("pass1_fragment", "BilateralFilter.glsl"))
#output.write(load_array("pass1_fragment", "AOFX_SeparableFilter\FilterCommon.glsl"))
#output.write(load_array("pass1_fragment", "AOFX_SeparableFilter\FilterKernel.glsl"))
#output.write(load_array("pass1_fragment", "AOFX_SeparableFilter\HorizontalFilter.glsl"))
#output.write(load_array("pass1_fragment", "AOFX_SeparableFilter\VerticalFilter.glsl"))
output.close()
