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
 * Main program start point
 *
 * Copyright: Copyright Jonathan MERCIER  2012-.
 *
 * License:   GPLv3+
 *
 * Authors:   Jonathan MERCIER aka bioinfornatics
 *
 * Source: dbuilder/main.d
 */
module dbuilder.main;

import std.array;
import std.exception;
import std.string;
import std.stdio;
import std.getopt;
import std.file;
import std.path;
import std.conv;
import std.parallelism;
import std.c.process;
import std.process;
import std.algorithm;

version( Posix )
    import core.sys.posix.sys.stat;

import dbuilder.ini;
import dbuilder.information;

enum    string cachedir            = ".cache";
enum    string configCacheFile     = buildNormalizedPath( cachedir, "dbuilder.cfg" );
enum    string buildCacheFile      = buildNormalizedPath( cachedir, "build.cfg" );
enum    string dbuilder_version    = "0.1.3";
shared  size_t verbosity           = 1;

struct Dfiles{
    string sources;
    string objects;
    string documentations;
    string interfaces;
    string includeDir;
}

void configure( string[] args ){
    int                         jobNumber           = -1;
    size_t                      arch                = 0;
    string                      builddir            = "";
    string                      destdir             = "";
    string                      prefix              = "";
    string                      bindir              = "";
    string                      datadir             = "";
    string                      docdir              = "";
    string                      includedir          = "";
    string                      libdir              = "";
    string                      pkgconfigdir        = "";
    string                      importsdir          = "";
    string                      compiler            = "";
    string                      dflags              = "";
    string                      linktolib           = "";
    string                      projectName         = "";
    string[][string]            sourceDir           = null;
    string[][string]            sourceFiles         = null;
    string[][string]            packageDir          = null;
    string[][string][string]    excludeModule       = null;
    BuildType                   type                = BuildType.unknown;
    string                      configFile          = "";
    string                      projectVersion      = "";

    void toHash( ref string[][string] hash, ref string var ){
        sizediff_t position = var.countUntil(':');
        string     key      = "";
        if( position < 0 ){
            position = 0;
            key = "unknown";
        }
        else
            key = var[0 .. position];

        hash[key] = var[position + 1 .. $].split(",");

    }
    void excludeModuleToHash( string option, string value ){
        string[][string] hash;
        sizediff_t position = value.countUntil(':');
        string     key      = "";
        if( position < 0 ){
            position = 0;
            key = "unknown";
        }
        else
            key = value[0 .. position];
        toHash( hash, value[position + 1 .. $]);
        excludeModule[key] = hash;
    }
    void packageDirToHash( string option, string value ){
        toHash( packageDir, value);
    }
    void sourceDirToHash( string option, string value ){
        toHash( sourceDir, value);
    }
    void sourceFilesToHash( string option, string value ){
        toHash( sourceFiles, value);
    }
    void help(){
        writeln( "Usage: dbuilder configure "                                                                           );
        writeln( "Options:"                                                                                             );
        writeln( "    --projectversion   Set project version (usefull for shared library)"                              );
        writeln( "    --compiler         Set compiler name"                                                             );
        writeln( "    --arch -m          Set pefix architecture used to build  : -m32 -m64"                             );
        writeln( "    --destdir          Set a chroot path usefull to inatll in your Home directory"                    );
        writeln( "    --prefix           Set pefix path   "                                                             );
        writeln( "    --bindir           Set path to binary directory"                                                  );
        writeln( "    --datadir          Set path to data directory"                                                    );
        writeln( "    --docdir           Set path to doc directory"                                                     );
        writeln( "    --includedir       Set path to include directory"                                                 );
        writeln( "    --libdir           Set path to library directory"                                                 );
        writeln( "    --pkgconfigdir     Set path to pkgconfig directory"                                               );
        writeln( "    --dflags           Set D flag to append: \"-d -g -w -O3\""                                        );
        writeln( "    --import           Set path to import directory to use"                                           );
        writeln( "    --linktolib        Set libraryies to used for link againt the application"                        );
        writeln( "    --type             Build as static library, shared library or executable"                         );
        writeln( "    --job --j -j       Set number of job to execute"                                                  );
        writeln( "    --configFile       Set path to config file"                                                       );
        writeln( "    --name --n -n      Set project name"                                                              );
        writeln( "    --sourcedir        Set directory where source files are located: [project name]:<dir1>,<dir>..."  );
        writeln( "    --sourceFiles      Set source files path: [project name]:<file1>,<file2>..."                      );
        writeln( "    --packageDir       Set path to root package: [project name]:<package1>,<package2>..."             );
        writeln( "    --sourceFiles      Set source files path [project name]:<version identifier>:path1>,<path2>..."   );
        writeln( "    --help --h -h      display this message"                                                          );
        exit(0);
    }
    getopt(
        args,
        "projectversion",   &projectVersion     ,
        "compiler"      ,   &compiler           ,
        "arch|m"        ,   &arch               ,
        "destdir"       ,   &destdir            ,
        "prefix"        ,   &prefix             ,
        "builddir"      ,   &builddir           ,
        "bindir"        ,   &bindir             ,
        "datadir"       ,   &datadir            ,
        "docdir"        ,   &docdir             ,
        "includedir"    ,   &includedir         ,
        "libdir"        ,   &libdir             ,
        "pkgconfigdir"  ,   &pkgconfigdir       ,
        "dflags"        ,   &dflags             ,
        "import"        ,   &importsdir         ,
        "linktolib"     ,   &linktolib          ,
        "type"          ,   &type               ,
        "job|j"         ,   &jobNumber          ,
        "configFile"    ,   &configFile         ,
        "name|n"        ,   &projectName        ,
        "sourcedir"     ,   &sourceDirToHash    ,
        "sourceFiles"   ,   &sourceFilesToHash  ,
        "help|h"        ,   &help
    );

    if( verbosity > 0 )
        writeln("→ Executing the configuration");

    if( compiler.empty ){                           // if no compiler setted by user try to find one installed in current system
        compiler = getCompiler();
        assert( ! compiler.empty, "No D compiler found" );

        if( verbosity > 1 )
            writefln("\t Compiler: %s", compiler);
    }

    Section root    = new Section("root", 0);   // Where cache data will be stored
    Section project = null;

    Information info = getInformation( compiler );  // get information to selected D compiler
    IniFile iniFile;
    size_t  max;

    if(  configFile.empty ){                        // If no config file set from command line
        if( exists( "dbuilder.cfg" ) )              // check if in current dir dbuilder.cfg file exist
            configFile = "dbuilder.cfg";
        else if( exists( "dbuilder.ini" ) )         // or if dbuilder.ini file exist
            configFile = "dbuilder.ini";
    }

    if( ! configFile.empty ){                         // If they a config file load his parameter priorities give to command line
        if( verbosity > 1 )
            writefln("\t Reading config file: %s", configFile);
        iniFile     = dbuilder.ini.open( configFile );
        max         = iniFile.length;
    }
    else
        max = 1;

    for( size_t i = 0; i < max; i++ ){

        if( projectName.empty ){
            if( projectName !is null )
                projectName = iniFile[i].name;
            else
                projectName = "dproject";
        }
        if( verbosity > 1 )
            writefln("\t Configuring project: %s", projectName);

        project = new Section(projectName, 1);

        if( type != BuildType.unknown ){
            switch( type ){
                case BuildType.sharedLib:
                    project["type"] = "shared";
                    break;
                case BuildType.staticLib:
                    project["type"] ="static";
                    break;
                case BuildType.executable:
                    project["type"] = "executable";
                    break;
                default:
                    throw new Exception( "Unknown build type" );
            }
        }
        else if( iniFile !is null  && "type" in iniFile[i] )
            project["type"] = iniFile[i]["type"];
        else
            project["type"] = "executable";

        if( verbosity > 1 )
            writefln("\t Project set as: %s", project["type"]);

        if( jobNumber != -1 )
            project["jobs"] = to!string(jobNumber);
        else if( iniFile !is null  && "jobs" in iniFile[i] )
            project["jobs"] = iniFile[i]["jobs"];
        else
            project["jobs"] = to!string( totalCPUs );

        if( verbosity > 1 )
            writefln("\t Number of job to execute in same time: %s", project["jobs"]);

        if( ! destdir.empty )
            project["destdir"] = destdir;
        else if( iniFile !is null  && "destdir" in iniFile[i] )
            project["destdir"] = iniFile[i]["destdir"];
        else
             project["destdir"] = "";
        if( verbosity > 1 )
            writefln("\t Destination directory: %s", ( ! project["destdir"].empty ) ? project["destdir"] : "None");


        if( ! prefix.empty ){
            project["prefix"]   = prefix;
            info.dir.prefix         = prefix;
        }
        else if( iniFile !is null  && "prefix" in iniFile[i] ){
            project["prefix"]   = iniFile[i]["prefix"];
            info.dir.prefix         = prefix;
        }
        else
             project["prefix"] = info.dir.prefix;

        if( verbosity > 1 )
            writefln("\t Prefix: %s", project["prefix"]);
        if( ! bindir.empty )
            project["bindir"] = bindir;
        else if( iniFile !is null  && "bindir" in iniFile[i] )
            project["bindir"] = iniFile[i]["bindir"];
        else
             project["bindir"] = info.dir.bin;
        if( verbosity > 1 )
            writefln("\t Bin directory: %s", project["bindir"]);

        if( ! datadir.empty )
            project["datadir"] = datadir;
        else if( iniFile !is null  && "datadir" in iniFile[i] )
            project["datadir"] = iniFile[i]["datadir"];
        else
             project["datadir"] = info.dir.data;
        if( verbosity > 1 )
            writefln("\t Data directory: %s", project["datadir"]);

        if( ! docdir.empty  )
            project["docdir"] = docdir;
        else if( iniFile !is null  && "docdir" in iniFile[i] )
            project["docdir"] = iniFile[i]["docdir"];
        else
             project["docdir"] = info.dir.doc;
        if( verbosity > 1 )
            writefln("\t Documentation directory: %s", project["docdir"]);

        if( ! includedir.empty )
            project["includedir"] = includedir;
        else if( iniFile !is null  && "includedir" in iniFile[i] )
            project["includedir"] = iniFile[i]["includedir"];
        else
             project["includedir"] = info.dir.include;
        if( verbosity > 1 )
            writefln("\t Include directory: %s", project["includedir"]);

        if( ! libdir.empty )
            project["libdir"] = libdir;
        else if( iniFile !is null  && "libdir" in iniFile[i] )
            project["libdir"] = iniFile[i]["libdir"];
        else
             project["libdir"] = info.dir.lib;
        if( verbosity > 1 )
            writefln("\t Library directory: %s", project["libdir"]);

        if( ! pkgconfigdir.empty )
            project["pkgconfigdir"] = pkgconfigdir;
        else if( iniFile !is null  && "pkgconfigdir" in iniFile[i] )
            project["pkgconfigdir"] = iniFile[i]["pkgconfigdir"];
        else
             project["pkgconfigdir"] = info.dir.pkgconfig;
        if( verbosity > 1 )
            writefln("\t Package config directory: %s", project["pkgconfigdir"]);

        if( ! importsdir.empty )
            project["importsdir"] = importsdir;
        else if( iniFile !is null  && "importsdir" in iniFile[i] )
            project["importsdir"] = iniFile[i]["importsdir"];
        else if( !info.dir.imports.empty )
             project["importsdir"] = info.dir.imports.join(",");
        if( verbosity > 1 )
            writefln("\t Imports directories: %s", project["importsdir"].split(","));

        if( ! dflags.empty )
            project["dflags"] = dflags;
        else if(iniFile !is null   && "dflags" in iniFile[i])
            project["dflags"]  = iniFile[i]["dflags"];
        else
             project["dflags"] = info.dflags;
        if( verbosity > 1 )
            writefln("\t D flags: %s", project["dflags"]);

        if( ! linktolib.empty )
            project["linktolib"] = linktolib;
        else if(iniFile !is null   && "linktolib" in iniFile[i])
            project["linktolib"] = iniFile[i]["linktolib"];
        else if( !info.linktolib.empty )
             project["linktolib"] = info.linktolib.join(",");
        if( "linktolib" in project && verbosity > 1 )
            writefln("\t Libraries which we need to link against current project: %s", project["linktolib"].split(","));

        if( sourceDir !is null && projectName in sourceDir && ! sourceDir[projectName].empty )
            project["sourcedir"] = sourceDir[projectName].join(",");
        else if(iniFile !is null   && "sourcedir" in iniFile[i] && ! iniFile[i]["sourcedir"].empty )
            project["sourcedir"] = iniFile[i]["sourcedir"];

        if( sourceFiles !is null && projectName in sourceFiles && ! sourceFiles[projectName].empty )
            project["sourcefiles"] = sourceFiles[projectName].join(",");
        else if(iniFile !is null   && "sourcefiles" in iniFile[i] && ! iniFile[i]["sourcefiles"].empty )
            project["sourcefiles"] = iniFile[i]["sourcefiles"];

        if( packageDir !is null && projectName in packageDir && ! packageDir[projectName].empty )
            project["packagedir"] = packageDir[projectName].join(",");
        else if(iniFile !is null   && "packagedir" in iniFile[i] && ! iniFile[i]["packagedir"].empty )
            project["packagedir"] = iniFile[i]["packagedir"];

        if( "sourcedir" !in project && "sourcefiles" !in project && "packagedir" !in project )
            project["sourcedir"] = ["."].join(",");

        if( verbosity > 1 ){
            writefln("\t Source directory: %s"         , ( "sourcedir" in project && !project["sourcedir"].empty ) ? project["sourcedir"] : "None" );
            writefln("\t Source files: %s"             , ( "sourcefiles" in project && !project["sourcefiles"].empty ) ? project["sourcefiles"] : "None"  );
            writefln("\t Root package directory: %s"   , ( "packagedir" in project && !project["packagedir"].empty ) ? project["packagedir"] : "None"  );
        }

        if( ! builddir.empty )
            project["builddir"] = builddir;
        else
            project["builddir"] = "build";

        if( verbosity > 1 )
            writefln("\t Build directory: %s", project["builddir"]);

        project["compiler"] = compiler;

        if( arch != 0 )
            project["arch"] = to!string(arch);
        else
            project["arch"] = to!string(info.arch);

        if( ! projectVersion.empty )
            project["version"] = projectVersion;
        else if(iniFile !is null   && "version" in iniFile[i])
            project["version"]  = iniFile[i]["version"];
        else
            project["version"] = "0.0.1";
        if( verbosity > 1 )
            writefln("\t Project version set as: %s", project["version"]);

        project["linker"]           = info.flag.linker;
        project["dl"]               = info.flag.dl;
        project["fpic"]             = info.flag.fpic;
        project["output"]           = info.flag.output;
        project["headerFile"]       = info.flag.headerFile;
        project["docFile"]          = info.flag.docFile;
        project["noObj"]            = info.flag.noObj;
        project["ddeprecated"]      = info.flag.ddeprecated;
        project["ddoc_macro"]       = info.flag.ddoc_macro;
        project["dversion"]         = info.flag.dversion;
        project["soname"]           = info.flag.soname;
        project["phobos"]           = info.flag.phobos;
        project["druntime"]         = info.flag.druntime;
        project["staticLibExt"]     = info.static_lib_ext;
        project["dynamicLibExt"]    = info.dynamic_lib_ext;
        project["executableExt"]    = info.executable_ext;
        project["filter"]           = info.filter.join(",");
        root.addChild( project );
    }
    root.shrink;
    if( !exists( cachedir ) )
        mkdir( cachedir );
    else
        assert( isDir( cachedir ), "A file " ~ cachedir ~ " exist already then it is impossible to create a directory with same name" );

    File cacheInfo = File( configCacheFile, "w" );
    cacheInfo.write( project.toString() );
    cacheInfo.close();

}

void builder( string[] args ){
    void search( in string sourceDir, in string builddir, ref Dfiles[] dFiles, bool stripSourceDir = true ){
        DirEntry[] files = array(
                                dirEntries( sourceDir, SpanMode.depth )
                                .filter!( ( a ) =>  a.name.extension == ".d"  )
                            ) ;

        size_t oldLength = dFiles.length;
        dFiles.length    = oldLength + files.length;

        foreach( i, d; parallel(files, 1) ){
            size_t index                = oldLength + i;
            string baseName             = (stripSourceDir) ? d.stripExtension[sourceDir.length + 1 .. $]: d.stripExtension;
            dFiles[index].sources       = d;
            dFiles[index].objects       = buildNormalizedPath ( builddir , "objects"        ,  baseName ~ ".o" );
            dFiles[index].documentations= buildNormalizedPath ( builddir , "documentations" ,  baseName ~ ".html" );
            dFiles[index].interfaces    = buildNormalizedPath ( builddir , "imports"        ,  baseName ~ ".di" );
            if( stripSourceDir )
                dFiles[index].includeDir = sourceDir;
        }

    }
    if( !exists( configCacheFile ) )
        configure( [""] );
    if( verbosity > 0 )
        writeln("→ Executing the build");
    // Iterate over all *.d files in current directory and all its subdirectories auto dFiles = filter!`endsWith(a.name,".d")`(dirEntries(".",SpanMode.depth)); foreach(d; dFiles) writeln(d.name); // Hook it up with std.parallelism to compile them all in parallel: foreach(d; parallel(dFiles, 1)) //passes by 1 file to each thread { string cmd = "dmd -c " ~ d.name; writeln(cmd); std.process.system(cmd); }
    IniFile iniFile = dbuilder.ini.open( configCacheFile );                             // Load cache file
    const size_t max = iniFile.length;
    //~ defaultPoolThreads( to!uint(iniFile["jobs"]) );                                 // Set number of jobs to execute in same time

    IniFile buildInfo = new Section("root", 0);   // Where cache data will be stored

    for( size_t i = 0; i < max; i++ ){

        string   outFile = iniFile[i].name;
        Dfiles[] dFiles                 = [];
        Section  currentSection         = new Section(iniFile[i].name, 1);
        Section  objectsSection         = new Section("objects", 2);
        Section  documentationsSection  = new Section("documentations", 2);
        Section  importsSection         = new Section("imports", 2);
        Section  binarySection          = new Section("binary", 2);

        if( "sourcedir" in iniFile[i] ){

            foreach( f; iniFile[i]["sourcedir"] .split(","))
                search( f, iniFile[i]["builddir"], dFiles );
        }

        if( "packageDir" in iniFile[i] ){
            foreach( f; iniFile[i]["packageDir"] .split(","))
                search( f, iniFile[i]["builddir"], dFiles, false );
        }

        if( "sourcefiles" in iniFile[i] ){
            foreach( f; iniFile[i]["sourcefiles"] .split(","))
                search( f, iniFile[i]["builddir"], dFiles, false );
        }

        if( verbosity > 1 )
            writeln( dFiles );

        foreach( files; dFiles ){//todo use  iniFile["filter"]; use time to build, rebuild or do nothing

            bool needToBuild        = false;

            if( exists( files.objects ) ){
                DirEntry tmp1 = dirEntry( files.sources );
                DirEntry tmp2 = dirEntry( files.objects );
                if( tmp1.timeLastModified < tmp2.timeLastModified )
                    needToBuild = true;
            }
            else
                needToBuild = true;

            if( needToBuild ){
                string cmd = "%s %s".format( iniFile[i]["compiler"], iniFile[i]["dflags"] );  // add compiler and his D flags

                foreach( dir; iniFile[i]["importsdir"].split(","))                            // add dir to include
                    cmd ~= " -I%s".format( dir );

                if( !files.includeDir.empty)
                    cmd ~= " -I%s".format( files.includeDir );

                if( iniFile[i]["type"] == "shared" )
                    cmd ~= ( iniFile[i]["dl"].empty ) ? " " ~ iniFile[i]["fpic"]: " " ~ iniFile[i]["linker"] ~ iniFile[i]["dl"] ~ " " ~ iniFile[i]["fpic"];
                else if( iniFile[i]["type"] == "static" )
                    cmd ~= ( iniFile[i]["dl"].empty ) ? "" : " " ~ iniFile[i]["linker"] ~ iniFile["dl"];
                cmd ~= " -c %s %s%s %s%s %s%s".format (
                                                        files.sources           ,
                                                        iniFile[i]["output"]    ,
                                                        files.objects           ,
                                                        iniFile[i]["docFile"]   ,
                                                        files.documentations    ,
                                                        iniFile[i]["headerFile"],
                                                        files.interfaces
                                                    );

                if( verbosity > 1 )
                    writeln( cmd );

                system( cmd );
            }
        }

        foreach( files; dFiles ){
            objectsSection[ baseName(files.objects) ] = files.objects;
            documentationsSection[ baseName(files.documentations) ] = files.documentations;
            importsSection[ baseName(files.interfaces) ] = files.interfaces;
        }

        string[] oFiles = array( dFiles.map!( a => a.objects ).filter!( ( a ) =>  !a.empty ) );

        string output       = "";
        string linkingCmd   = "";

        switch(iniFile[i]["type"]){
            case("shared"):
                if( !exists("lib") )
                     mkdir( "lib" );
                else
                    assert( isDir("lib") , "A file \"lib\" exist already then it is impossible to create a directory with same name" );
                output = buildNormalizedPath( iniFile[i]["builddir"],"lib", "lib" ~ outFile ~  iniFile[i]["dynamicLibExt"] ~ "." ~ iniFile[i]["version"] );
                linkingCmd = "%s %s %s %s%s".format( iniFile[i]["compiler"], iniFile[i]["soname"], oFiles.join( " " ), iniFile[i]["output"], output);
                if( verbosity > 1 )
                    writeln( linkingCmd );
                system( linkingCmd );
                break;
            case("static"):
                if( !exists("lib") )
                     mkdir( "lib" );
                else
                    assert( isDir("lib") , "A file \"lib\" exist already then it is impossible to create a directory with same name" );

                output = buildNormalizedPath( iniFile[i]["builddir"],"lib", "lib" ~ outFile ~  iniFile[i]["dynamicLibExt"] );
                linkingCmd = "ar rcs %s %s".format( output, oFiles.join( " " ) );
                if( verbosity > 1 )
                    writeln( linkingCmd );
                system( linkingCmd );
                linkingCmd = "ranlib %s".format( output );
                if( verbosity > 1 )
                    writeln( linkingCmd );
                system( linkingCmd );
                break;
            case("executable"):
                version( Windows ){
                    if( extension(outFile) != ".exe" )
                        outFile ~= ".exe";
                }
                output = buildNormalizedPath( iniFile[i]["builddir"],"bin", outFile ~  iniFile[i]["executableExt"] );
                linkingCmd = "%s %s %s".format( iniFile[i]["compiler"], oFiles.join( " " ), iniFile[i]["output"], output );
                if( verbosity > 1 )
                    writeln( linkingCmd );
                system( linkingCmd );
                break;
            default:
                throw new Exception("Unknown build type %s".format( iniFile[i]["type"] ));
        }

        binarySection[ baseName(output) ] = output;

        currentSection.addChild( binarySection );
        currentSection.addChild( objectsSection );
        currentSection.addChild( documentationsSection );
        currentSection.addChild( importsSection );
        buildInfo.addChild( currentSection );
    }
    buildInfo.shrink;

    File cacheInfo = File( buildNormalizedPath( cachedir, "build.cfg"), "w" );
    cacheInfo.write( buildInfo.toString() );
    cacheInfo.close();

}

void cleaner( string[] args ){
    if( !exists( buildCacheFile ) ){
        writeln( "Nothing to clean!" );
        exit(1);
    }
    if( verbosity > 0 )
        writeln("→ Cleaning the project");

    IniFile iniFile     = dbuilder.ini.open( buildCacheFile );                          // Load cache file
    const size_t max    = iniFile.length;
    //~ defaultPoolThreads( to!uint(iniFile["jobs"]) );                                 // Set number of jobs to execute in same time

    for( size_t i = 0; i < max; i++ ){
        foreach( string value; iniFile[i].get("objects").values ~ iniFile[i].get("documentations").values ~ iniFile[i].get("imports").values ~ iniFile[i].get("binary").values ){
            if( exists( value ) ){
                if( verbosity > 1 )
                    writeln( "\t Removing file: " ~ value );
                remove( value );
            }
        }
    }


}

void installer( string[] args ){
    if( !exists( buildCacheFile ) )
        builder( [""] );
    if( verbosity > 0 )
        writeln("→ Installing the project");

    IniFile buildFile   = dbuilder.ini.open( buildCacheFile );                          // Load cache file
    IniFile configFile  = dbuilder.ini.open( configCacheFile );                         // Load cache file
    const size_t max    = buildFile.length;
    //~ defaultPoolThreads( to!uint(iniFile["jobs"]) );                                 // Set number of jobs to execute in same time

    for( size_t i = 0; i < max; i++ ){
        string prefixirProject      = buildNormalizedPath( configFile[i]["destdir"], configFile[i]["prefix"] );
        string bindirProject        = buildNormalizedPath( configFile[i]["destdir"], configFile[i]["bindir"] );
        string libdirProject        = buildNormalizedPath( configFile[i]["destdir"], configFile[i]["libdir"] );
        string includedirProject    = buildNormalizedPath( configFile[i]["destdir"], configFile[i]["includedir"] );
        string docdirProject        = buildNormalizedPath( configFile[i]["destdir"], configFile[i]["docdir"] );
        string buildDocDir          = buildNormalizedPath( configFile[i]["builddir"], "doc" );
        string buildImportsDir      = buildNormalizedPath( configFile[i]["builddir"], "imports" );
        string buildbinDir          = buildNormalizedPath( configFile[i]["builddir"], "bin" );
        string buildlibDir          = buildNormalizedPath( configFile[i]["builddir"], "lib" );
        Section currentBuild        = buildFile.get(configFile[i].name);

        if( !exists( configFile[i]["prefix"] ) )
            mkdirRecurse( prefixirProject );
        if( !exists( bindirProject ) )
            mkdirRecurse( bindirProject );
        if( !exists( libdirProject ) )
            mkdirRecurse( libdirProject );
        if( !exists( includedirProject ) )
            mkdirRecurse( includedirProject );
        if( !exists( docdirProject ) )
            mkdirRecurse( docdirProject );

        foreach( diFiles; currentBuild.get("imports").values ){
            string dest = diFiles.replace( buildImportsDir, includedirProject );
            if( verbosity > 1 )
                writeln( "Copy ",  diFiles, " to ", dest);
            string installDir = dirName( dest );
            if( !exists( installDir ) )
                mkdirRecurse( installDir );
            copy( diFiles, dest );
        }

        foreach( docFiles; currentBuild.get("documentations").values ){
            string dest = docFiles.replace( buildDocDir, docdirProject );
            if( verbosity > 1 )
                writeln( "Copy ",  docFiles, " to ", dest);
            string installDir = dirName( dest );
            if( !exists( installDir ) )
                mkdirRecurse( installDir );
            copy( docFiles, dest );
        }


        switch(configFile[i]["type"]){
            case("shared"):
                if( !exists( libdirProject ) )
                    mkdirRecurse( libdirProject );
                foreach( binFiles; currentBuild.get("binary").values ){
                    string dest = binFiles.replace( buildlibDir, libdirProject );
                    if( verbosity > 1 )
                        writeln( "Copy ",  binFiles, " to ", dest);
                    copy(binFiles, dest);
                }
                break;
            case("static"):
                if( !exists( libdirProject ) )
                    mkdirRecurse( libdirProject );
                foreach( binFiles; currentBuild.get("binary").values ){
                    string dest = binFiles.replace( buildlibDir, libdirProject );

                    if( verbosity > 1 )
                        writeln( "Copy ",  binFiles, " to ", dest);

                    copy(binFiles, dest);
                }
                break;
            case("executable"):
                if( !exists( bindirProject ) )
                    mkdirRecurse( bindirProject );
                foreach( binFiles; currentBuild.get("binary").values ){
                    string dest = binFiles.replace( buildbinDir, bindirProject );

                    if( verbosity > 1 )
                        writeln( "Copy ",  binFiles, " to ", dest);

                    copy(binFiles, dest);
                    version( Posix )
                        chmod( dest.toStringz, S_IRUSR| S_IWUSR| S_IXUSR | S_IRGRP| S_IXGRP| S_IROTH | S_IXOTH );
                }
                break;
            default:
                throw new Exception("Unknown build type %s".format( configFile[i]["type"] ));
        }
    }

}

void main( string[] args ){

    void verbose( string option ){
        switch( option ){
            case("v"):
            case("verbose"):
                verbosity += 1;
                break;
            case("quiet"):
                verbosity = 0;
                break;
            default:
                verbosity = 1;
                break;
        }
    }

    void displayVersion(){
        writefln( "DBuilder v%s", dbuilder_version );
    }

    void help(){
        writeln( "Usage: dbuilder [target] [options]"                                           );
        writeln( "Target:"                                                                      );
        writeln( "     configure"                                                              );
        writeln( "     build"                                                                  );
        writeln( "     clean"                                                                  );
        writeln( "     install"                                                                );
        writeln( "Options:"                                                                     );
        writeln( "    --verbose --v -v   Increase verbosity level"                              );
        writeln( "    --quiet            Disable verbosity"                                     );
        writeln( "    --version          Display wich version is used"                          );
        writeln( "    --help --h -h      display this message"                                  );
        exit(0);
    }

    if( args.length == 1 )
        help();

    long[string]        targets     = ["configure": -1, "build": -1, "clean": -1, "install": -1, "all": -1 ];
    string[][string]    arguments   = ["configure": [], "build": [], "clean": [], "install": [] ];

    foreach( key, ref value; targets )
        value = args.countUntil(key);

    size_t end  = 0;
    size_t start= 0;

    if( targets["configure"] != -1 ){
        start       = cast(size_t) targets["configure"];
        auto tmp    = filter!((a) => a > start)(targets.values);
        if( !tmp.empty ){
            size_t value = cast(size_t) reduce!(min)(tmp);
            if( value == size_t.max )
                end = args.length;
            else
                end = value;
        }
        else
            end = args.length;
        arguments["configure"] = args[0] ~ args[ start .. end ];
        args = args[0 .. start] ~ args[end .. $];
    }

    if( exists(configCacheFile) ){
        if( targets["build"] != -1 ){
            start       = cast(size_t) targets["build"];
            auto tmp    = filter!((a) => a > start)(targets.values);
            if( !tmp.empty ){
                size_t value = cast(size_t) reduce!(min)(tmp);
                if( value == size_t.max )
                    end = args.length;
                else
                    end = value;
            }
            else
                end = args.length;
            arguments["build"] = args[0] ~ args[ start .. end ];
            args = args[0 .. start] ~ args[end .. $];
        }
        if( targets["clean"] != -1 ){
            start       = cast(size_t) targets["clean"];
            auto tmp    = filter!((a) => a > start)(targets.values);
            if( !tmp.empty ){
                size_t value = cast(size_t) reduce!(min)(tmp);
                if( value == size_t.max )
                    end = args.length;
                else
                    end = value;
            }
            else
                end = args.length;
            arguments["clean"] = args[0] ~ args[ start.. end ] ;
            args = args[0 .. start] ~ args[end .. $];
        }
        if( targets["install"] != -1 ){
            start       = cast(size_t) targets["install"];
            auto tmp    = filter!((a) => a > start)(targets.values);
            if(!tmp.empty ){
                size_t value = cast(size_t) reduce!(min)(tmp);
                if( value == size_t.max )
                    end = args.length;
                else
                    end = value;
            }
            else
                end = args.length;
            arguments["install"] = args[0] ~ args[ start .. end ] ;
            args = args[0 .. start] ~ args[end .. $];
        }

    }
    else if( targets["build"] != -1 || targets["clean"] != -1 || targets["install"] != -1 )
       writeln( "Warning: configure, build and install step are turn to automatic mode" );

    getopt(
        args,
        std.getopt.config.bundling              ,
        "verbose"           , &verbose          ,
        "quiet"             , &verbose          ,
        "v"                 , &verbose          ,
        "version"           , &displayVersion   ,
        "help|h"            , &help
    );

    if( targets["configure"] != -1 )
        configure( arguments["configure"] );

    if( targets["build"] != -1 )
        builder( arguments["configure"] );

    if( targets["clean"] != -1 )
        cleaner( arguments["clean"] );

    if( targets["install"] != -1 )
        installer( arguments["install"] );

}
