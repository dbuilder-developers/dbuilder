/*
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301, USA.
 *
 */

/**
 * Compiler provides informations about each D compiler
 *
 * Copyright: Copyright Jonathan MERCIER  2012-.
 *
 * License:   GPLv3+
 *
 * Authors:   Jonathan MERCIER aka bioinfornatics
 *
 * Source: dbuilder/compiler.d
 */
module dbuilder.information;

 import std.path;
 import std.file;
 import std.string;
 import std.process;
 import std.system;
 import std.array;

enum BuildType{
    unknown,
    executable,
    staticLib,
    sharedLib
}

struct  InformationDir {
    private:
    string      _bin        = "bin";
    string      _data       = "share";
    string      _doc        = "doc";
    string      _include    = "include" ~ dirSeparator ~ "d";
    string[]    _imports    = ["include" ~ dirSeparator ~ "d"];
    string      _lib        = "lib";
    string      _pkgconfig  = "pkgconfig";
    public:
    string  prefix;
    string  destdir;

    @property
    string  bin(){
        return buildNormalizedPath( prefix, _bin);
    }
    @property
    void  bin( string value ){
        _bin = value;
    }

    @property
    string  data(){
        return buildNormalizedPath( prefix, _data);
    }
    @property
    void  data( string value ){
        _data = value;
    }

    @property
    string  doc(){
        return buildNormalizedPath( data, _doc );
    }
    @property
    void  doc( string value ){
        _doc = value;
    }

    @property
    string  include(){
        return buildNormalizedPath(  prefix, _include);
    }
    @property
    void  include( string value ){
       _include = value;
    }

    @property
    string[]  imports(){
        string[] result = new string[]( _imports.length );
        foreach( size_t counter, dir; _imports )
            result[counter] = buildNormalizedPath( prefix, dir );
        return result;
    }
    @property
    void  imports( string value ){
       _imports = value.split(",");
    }
    @property
    void  imports( string[] value ){
       _imports = value;
    }

    @property
    string  lib(){
        return buildNormalizedPath( prefix, _lib );
    }
    @property
    void  lib( string value ){
        _lib = value;
    }

    @property
    string  pkgconfig(){
        return buildNormalizedPath( data, _pkgconfig );
    }
    @property
    void  pkgconfig( string value ){
        _pkgconfig = value;
    }
}

struct InformationFlag{
    string  linker;
    string  dl;
    string  fpic;
    string  objectFile;
    string  objectDir;
    string  headerFile;
    string  headerDir;
    string  docFile;
    string  docDir;
    string  noObj;
    string  ddeprecated;
    string  ddoc_macro;
    string  dversion;
    string  soname;
    string  phobos;
    string  druntime;
}

struct Information{
    private:
        string[] _linktolib;
    public:
    OS              os;
    string          static_lib_ext;
    string          dynamic_lib_ext;
    string          executable_ext;
    string[]        filter;
    string          dflags;
    size_t          jobs;
    BuildType       type;
    size_t          arch;
    InformationDir  dir;
    InformationFlag flag;

    @property
    string[]  linktolib(){
        return _linktolib;
    }
    @property
    void  linktolib( string value ){
       _linktolib = value.split(",");
    }
    @property
    void  linktolib( string[] value ){
       _linktolib = value;
    }

}

Information getInformation( string compiler ){
    Information info;
    version(Windows){

        info.static_lib_ext = ".lib";
        info.dynamic_lib_ext= ".dll";
        info.executable_ext = ".exe";
        info.filter         = ["linux", "darwin", "freebsd", "openbsd", "solaris"];

        version(Win32){
            info.os         = OS.win32;
            info.dir.prefix     = getenv("ProgramFiles");
        }
        else version(Win64){
            info.os         = OS.win64;
            info.dir.prefix     = getenv("ProgramFiles(x86)");
        }
    }
    else version(Posix){

        info.static_lib_ext = ".a";
        info.dynamic_lib_ext= ".so";
        info.executable_ext = "";
        info.dir.prefix     = "/usr/local";

        version(linux){
            info.os         = OS.linux;
            info.filter     = ["windows", "darwin", "freebsd", "openbsd", "solaris"];
            info.flag.dl    = "-ldl";
        }
        else version(OSX){
            info.os         = OS.osx;
            info.filter     = ["windows", "linux", "freebsd", "openbsd", "solaris"];
        }
        else version(FreeBSD){
            info.os         = OS.freeBSD;
            info.filter     = ["windows", "linux", "darwin", "openbsd", "solaris"];
        }
        else version(OpenBSD){
            info.os         = OS.otherPosix;
            info.filter     = ["windows", "linux", "freebsd", "darwin", "solaris"];
        }
        else version(Solaris){
            info.os         = OS.solaris;
            info.filter     = ["windows", "linux", "freebsd", "openbsd", "darwin"];
        }

    }
    else
        static assert(false, "Unsuported plateform");

    version(X86)
        info.arch = 32;
    else version(X86_64)
        info.arch = 64;
    else
        static assert(false, "Unsuported architecture");
    switch( compiler ){
        case( "ldc" ):
        case( "ldc2" ):
        case( "ldmd" ):
            info.dflags             = "-O2";
            info.flag.linker        = "-L";
            info.flag.fpic          = "-relocation-model=pic";
            info.flag.objectFile    = "-of";
            info.flag.objectDir     = "-od";
            info.flag.headerFile    = "-Hf";
            info.flag.headerDir     = "-Hd";
            info.flag.docFile       = "-Df";
            info.flag.docDir        = "-Dd";
            info.flag.noObj         = "-o-";
            info.flag.ddeprecated   = "-d";
            info.flag.ddoc_macro    = "";
            info.flag.dversion      = "-d-version";
            info.flag.soname        = "-shared";
            info.flag.phobos        = "phobos-ldc";
            info.flag.druntime      = "druntime-ldc";
            break;
        case( "gdc" ):
        case( "gdc2" ):
        case( "gdmd" ):
            info.dflags             = "-O2";
            info.flag.linker        = "-Xlinker";
            info.flag.fpic          = "-fPIC";
            info.flag.objectFile    = "-o";
            info.flag.objectDir     = "-fod=";
            info.flag.headerFile    = "-fintfc-file=";
            info.flag.headerDir     = "-fintfc-dir";
            info.flag.docFile       = "-fdoc-file=";
            info.flag.docDir        = "-fdoc-dir=";
            info.flag.noObj         = "-fsyntax-only";
            info.flag.ddeprecated   = "-fdeprecated";
            info.flag.ddoc_macro    = "-fdoc-inc=";
            info.flag.dversion      = "-fversion";
            info.flag.soname        = info.flag.linker ~ "-soname";
            info.flag.phobos        = "gphobos2";
            info.flag.druntime      = "gdruntime";
            break;
        case( "dmd" ):
        case( "dmd2" ):
            info.dflags             = "-O";
            info.flag.linker        = "-L";
            info.flag.fpic          = "-fPIC";
            info.flag.objectFile    = "-of";
            info.flag.objectDir     = "-od";
            info.flag.headerFile    = "-Hf";
            info.flag.headerDir     = "-Hd";
            info.flag.docFile       = "-Df";
            info.flag.docDir        = "-Dd";
            info.flag.noObj         = "-o-";
            info.flag.ddeprecated   = "-d";
            info.flag.ddoc_macro    = "";
            info.flag.dversion      = "-version";
            info.flag.soname        = info.flag.linker ~ "-soname";
            info.flag.phobos        = "phobos2";
            info.flag.druntime      = "druntime";
            break;
        default:
            throw new Exception("compiler %s not supported".format( compiler ));
    }

    return info;
}


bool compilerIsPresent( string compiler ){
    version(Windows)
        compiler ~= ".exe";
    string[] pathList   =  getenv( "PATH" ).split(pathSeparator);
    bool isSearching    = true;
    bool result         = false;
    size_t currentIndex = 0;

    while( isSearching ){
        if( currentIndex >= pathList.length )
            isSearching = false;
        else{
            string currentPath = buildPath( pathList[currentIndex], compiler );
            if( exists( currentPath ) ){
                isSearching = false;
                result      = true;
            }
            else
                currentIndex++;
        }
    }
    return result;
}


string getCompiler(){
    enum    string[] compilers  = ["dmd", "dmd2", "gdc", "gdc2", "gdmd", "ldc", "ldc2", "ldmd" ];
    bool    isSearching         = true;
    string  result              = "";
    size_t  currentIndex        = 0;

    while( isSearching ){
        if( currentIndex >= compilers.length )
            isSearching = false;
        else if( compilerIsPresent(compilers[currentIndex]) ){
            isSearching = false;
            result      = compilers[currentIndex];
        }
        currentIndex++;
    }
    return result;
}
