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

import dbuilder.ini;
import dbuilder.information;

enum    string cachedir            = ".cache";
enum    string configCacheFile     = buildNormalizedPath( cachedir, "dbuilder.cfg" );
enum    string buildCacheFile      = buildNormalizedPath( cachedir, "build.cfg" );
enum    string dbuilder_version    = "0.0.1";
shared  size_t verbosity           = 1;

void configure( string[] args ){
    int         jobNumber           = -1;
    size_t      arch                = 0;
    string      builddir            = "";
    string      destdir             = "";
    string      prefix              = "";
    string      bindir              = "";
    string      datadir             = "";
    string      docdir              = "";
    string      includedir          = "";
    string      libdir              = "";
    string      pkgconfigdir        = "";
    string      importsdir          = "";
    string      compiler            = "";
    string      dflags              = "";
    string      linktolib           = "";
    string      projectName         = "out";
    string      sourceDir           = "";
    string      sourceFiles         = "";
    BuildType   type                = BuildType.unknown;
    string      configFile          = "";
    string      projectVersion      = "";

    void help(){
        writeln( "Usage: dbuilder configure "                                                   );
        writeln( "Options:"                                                                     );
        writeln( "    --projectversion   Set project version (usefull for shared library)"      );
        writeln( "    --compiler         Set compiler name"                                     );
        writeln( "    --bindir           Set path to binary directory"                          );
        writeln( "    --datadir          Set path to data directory"                            );
        writeln( "    --docdir           Set path to doc directory"                             );
        writeln( "    --includedir       Set path to include directory"                         );
        writeln( "    --libdir           Set path to library directory"                         );
        writeln( "    --pkgconfigdir     Set path to pkgconfig directory"                       );
        writeln( "    --dflags           Set D flag to append"                                  );
        writeln( "    --import           Set path to import directory to use"                   );
        writeln( "    --linktolib        Set libraryies to used for link againt the application");
        writeln( "    --type             Build as static library, shared library or executable" );
        writeln( "    --job --j -j       Set number of job to execute"                          );
        writeln( "    --configFile       Set path to config file"                               );
        writeln( "    --name --n -n      Set project name"                                      );
        writeln( "    --sourcedir        Set directory where source files are located"          );
        writeln( "    --sourceFiles      Set source files path (separated by coma)"             );
        writeln( "    --help --h -h      display this message"                                  );
        exit(0);
    }
    getopt(
        args,
        "projectversion",   &projectVersion ,
        "compiler"      ,   &compiler       ,
        "arch|m"        ,   &arch           ,
        "destdir"       ,   &destdir        ,
        "prefix"        ,   &prefix         ,
        "builddir"      ,   &builddir       ,
        "bindir"        ,   &bindir         ,
        "datadir"       ,   &datadir        ,
        "docdir"        ,   &docdir         ,
        "includedir"    ,   &includedir     ,
        "libdir"        ,   &libdir         ,
        "pkgconfigdir"  ,   &pkgconfigdir   ,
        "dflags"        ,   &dflags         ,
        "import"        ,   &importsdir     ,
        "linktolib"     ,   &linktolib      ,
        "type"          ,   &type           ,
        "job|j"         ,   &jobNumber      ,
        "configFile"    ,   &configFile     ,
        "name|n"        ,   &projectName    ,
        "sourcedir"     ,   &sourceDir      ,
        "sourceFiles"   ,   &sourceFiles    ,
        "help|h"        ,   &help
    );

    if( verbosity > 0 )
        writeln("→ Executing the configuration");

    if( sourceDir == "" && sourceFiles == "" )
        sourceDir = ".";


    if( verbosity > 1 ){
        writefln("\t Source directory: %s" , (sourceDir != "")     ? sourceDir     : "any" );
        writefln("\t Source files: %s"     , (sourceFiles != "")   ? sourceFiles   : "any" );
    }

    if( compiler == "" ){                           // if no compiler setted by user try to find one installed in current system
        compiler = getCompiler();
        assert( compiler != "", "No D compiler found" );

        if( verbosity > 1 )
            writefln("\t Compiler: %s", compiler);
    }

    Section root        = new Section("root", 0);   // Where cache data will be stored
    Section projectInfo = null;

    Information info = getInformation( compiler );  // get information to selected D compiler
    IniFile iniFile;
    size_t  max;

    if(  configFile == "" ){                        // If no config file set from command line
        if( exists( "dbuilder.cfg" ) )              // check if in current dir dbuilder.cfg file exist
            configFile = "dbuilder.cfg";
        else if( exists( "dbuilder.ini" ) )         // or if dbuilder.ini file exist
            configFile = "dbuilder.ini";
    }

    if( configFile != "" ){                         // If they a config file load his parameter priorities give to command line
        if( verbosity > 1 )
            writefln("\t Reading config file: %s", configFile);
        iniFile     = dbuilder.ini.open( configFile );
        max         = iniFile.length;
    }
    else
        max = 1;

    for( size_t i = 0; i < max; i++ ){

        if( projectName == "" ){
            if( iniFile !is null )
                projectName = iniFile[i].name;
            else
                projectName = "dproject";
        }
        if( verbosity > 1 )
            writefln("\t Configuring project: %s", projectName);

        projectInfo = new Section(projectName, 1);

        if( type != BuildType.unknown ){
            switch( type ){
                case BuildType.sharedLib:
                    projectInfo["type"] = "shared";
                    break;
                case BuildType.staticLib:
                    projectInfo["type"] ="static";
                    break;
                case BuildType.executable:
                    projectInfo["type"] = "executable";
                    break;
                default:
                    throw new Exception( "Unknown build type" );
            }
        }
        else if( iniFile !is null  && "type" in iniFile[i] )
            projectInfo["type"] = iniFile[i]["type"];
        else
            projectInfo["type"] = "executable";

        if( verbosity > 1 )
            writefln("\t Project set as: %s", projectInfo["type"]);

        if( jobNumber != -1 )
            projectInfo["jobs"] = to!string(jobNumber);
        else if( iniFile !is null  && "jobs" in iniFile[i] )
            projectInfo["jobs"] = iniFile[i]["jobs"];
        else
            projectInfo["jobs"] = to!string( totalCPUs );

        if( verbosity > 1 )
            writefln("\t Number of job to execute in same time: %s", projectInfo["jobs"]);

        if( destdir != "" )
            projectInfo["destdir"] = destdir;
        else if( iniFile !is null  && "destdir" in iniFile[i] )
            projectInfo["destdir"] = iniFile[i]["destdir"];
        else
             projectInfo["destdir"] = "";
        if( verbosity > 1 )
            writefln("\t Destination directory: %s", ( projectInfo["destdir"] != "" ) ? projectInfo["destdir"] : "any");


        if( prefix != "" ){
            projectInfo["prefix"]   = prefix;
            info.dir.prefix         = prefix;
        }
        else if( iniFile !is null  && "prefix" in iniFile[i] ){
            projectInfo["prefix"]   = iniFile[i]["prefix"];
            info.dir.prefix         = prefix;
        }
        else
             projectInfo["prefix"] = info.dir.prefix;

        if( verbosity > 1 )
            writefln("\t Prefix: %s", projectInfo["prefix"]);
        if( bindir != "" )
            projectInfo["bindir"] = bindir;
        else if( iniFile !is null  && "bindir" in iniFile[i] )
            projectInfo["bindir"] = iniFile[i]["bindir"];
        else
             projectInfo["bindir"] = info.dir.bin;
        if( verbosity > 1 )
            writefln("\t Bin directory: %s", projectInfo["bindir"]);

        if( datadir != "" )
            projectInfo["datadir"] = datadir;
        else if( iniFile !is null  && "datadir" in iniFile[i] )
            projectInfo["datadir"] = iniFile[i]["datadir"];
        else
             projectInfo["datadir"] = info.dir.data;
        if( verbosity > 1 )
            writefln("\t Data directory: %s", projectInfo["datadir"]);

        if( docdir != ""  )
            projectInfo["docdir"] = docdir;
        else if( iniFile !is null  && "docdir" in iniFile[i] )
            projectInfo["docdir"] = iniFile[i]["docdir"];
        else
             projectInfo["docdir"] = info.dir.doc;
        if( verbosity > 1 )
            writefln("\t Documentation directory: %s", projectInfo["docdir"]);

        if( includedir != "" )
            projectInfo["includedir"] = includedir;
        else if( iniFile !is null  && "includedir" in iniFile[i] )
            projectInfo["includedir"] = iniFile[i]["includedir"];
        else
             projectInfo["includedir"] = info.dir.include;
        if( verbosity > 1 )
            writefln("\t Include directory: %s", projectInfo["includedir"]);

        if( libdir != "" )
            projectInfo["libdir"] = libdir;
        else if( iniFile !is null  && "libdir" in iniFile[i] )
            projectInfo["libdir"] = iniFile[i]["libdir"];
        else
             projectInfo["libdir"] = info.dir.lib;
        if( verbosity > 1 )
            writefln("\t Library directory: %s", projectInfo["libdir"]);

        if( pkgconfigdir != "" )
            projectInfo["pkgconfigdir"] = pkgconfigdir;
        else if( iniFile !is null  && "pkgconfigdir" in iniFile[i] )
            projectInfo["pkgconfigdir"] = iniFile[i]["pkgconfigdir"];
        else
             projectInfo["pkgconfigdir"] = info.dir.pkgconfig;
        if( verbosity > 1 )
            writefln("\t Package config directory: %s", projectInfo["pkgconfigdir"]);

        if( importsdir != "" )
            projectInfo["importsdir"] = importsdir;
        else if( iniFile !is null  && "importsdir" in iniFile[i] )
            projectInfo["importsdir"] = iniFile[i]["importsdir"];
        else if( !info.dir.imports.empty )
             projectInfo["importsdir"] = info.dir.imports.join(",");
        if( verbosity > 1 )
            writefln("\t Imports directories: %s", projectInfo["importsdir"].split(","));

        if( dflags != "" )
            projectInfo["dflags"] = dflags;
        else if(iniFile !is null   && "dflags" in iniFile[i])
            projectInfo["dflags"]  = iniFile[i]["dflags"];
        else
             projectInfo["dflags"] = info.dflags;
        if( verbosity > 1 )
            writefln("\t D flags: %s", projectInfo["dflags"]);

        if( linktolib != "" )
            projectInfo["linktolib"] = linktolib;
        else if(iniFile !is null   && "linktolib" in iniFile[i])
            projectInfo["linktolib"] = iniFile[i]["linktolib"];
        else if( !info.linktolib.empty )
             projectInfo["linktolib"] = info.linktolib.join(",");
        if( "linktolib" in projectInfo && verbosity > 1 )
            writefln("\t Libraries which we need to link against current project: %s", projectInfo["linktolib"].split(","));

        if( sourceDir != "" )
            projectInfo["sourcedir"] = sourceDir;

        if( sourceFiles != "" )
            projectInfo["sourcefiles"] = sourceFiles;

        if( builddir != "" )
            projectInfo["builddir"] = builddir;
        else
            projectInfo["builddir"] = "build";

        if( verbosity > 1 )
            writefln("\t Build directory: %s", projectInfo["builddir"]);

        projectInfo["compiler"] = compiler;

        if( arch != 0 )
            projectInfo["arch"] = to!string(arch);
        else
            projectInfo["arch"] = to!string(info.arch);

        if( projectVersion != "" )
            projectInfo["version"] = projectVersion;
        else if(iniFile !is null   && "version" in iniFile[i])
            projectInfo["version"]  = iniFile[i]["version"];
        else
            projectInfo["projectVersion"] = "0.0.1";
        if( verbosity > 1 )
            writefln("\t Project version set as: %s", projectInfo["projectVersion"]);

        projectInfo["linker"]           = info.flag.linker;
        projectInfo["dl"]               = info.flag.dl;
        projectInfo["fpic"]             = info.flag.fpic;
        projectInfo["output"]           = info.flag.output;
        projectInfo["headerFile"]       = info.flag.headerFile;
        projectInfo["docFile"]          = info.flag.docFile;
        projectInfo["noObj"]            = info.flag.noObj;
        projectInfo["ddeprecated"]      = info.flag.ddeprecated;
        projectInfo["ddoc_macro"]       = info.flag.ddoc_macro;
        projectInfo["dversion"]         = info.flag.dversion;
        projectInfo["soname"]           = info.flag.soname;
        projectInfo["phobos"]           = info.flag.phobos;
        projectInfo["druntime"]         = info.flag.druntime;
        projectInfo["staticLibExt"]     = info.static_lib_ext;
        projectInfo["dynamicLibExt"]    = info.dynamic_lib_ext;
        projectInfo["executableExt"]    = info.executable_ext;
        projectInfo["filter"]           = info.filter.join(",");
        root.addChild( projectInfo );
    }
    root.shrink;
    if( !exists( cachedir ) )
        mkdir( cachedir );
    else
        assert( isDir( cachedir ), "A file " ~ cachedir ~ " exist already then it is impossible to create a directory with same name" );

    File cacheInfo = File( configCacheFile, "w" );
    cacheInfo.write( projectInfo.toString() );
    cacheInfo.close();

}

void builder( string[] args ){
    if( verbosity > 0 )
        writeln("→ Executing the build");
    // Iterate over all *.d files in current directory and all its subdirectories auto dFiles = filter!`endsWith(a.name,".d")`(dirEntries(".",SpanMode.depth)); foreach(d; dFiles) writeln(d.name); // Hook it up with std.parallelism to compile them all in parallel: foreach(d; parallel(dFiles, 1)) //passes by 1 file to each thread { string cmd = "dmd -c " ~ d.name; writeln(cmd); std.process.system(cmd); }
    IniFile iniFile = dbuilder.ini.open( configCacheFile );                             // Load cache file
    const size_t max = iniFile.length;
    //~ defaultPoolThreads( to!uint(iniFile["jobs"]) );                                 // Set number of jobs to execute in same time

    IniFile buildInfo = new Section("root", 0);   // Where cache data will be stored

    for( size_t i = 0; i < max; i++ ){

        DirEntry[] dFiles;
        DirEntry[] oFiles;
        DirEntry[] docFiles;
        DirEntry[] diFiles;
        string   outFile = iniFile[i].name;
        Section currentSection          = new Section(iniFile[i].name, 1);
        Section objectsSection          = new Section("objects", 2);
        Section documentationsSection   = new Section("documentations", 2);
        Section importsSection          = new Section("imports", 2);

        if( "sourcedir" in iniFile[i] )
            dFiles = array( dirEntries( iniFile[i]["sourcedir"], SpanMode.depth).filter!((a) => endsWith(a.name, ".d")) );


        if( "sourcefiles" in iniFile[i] ){
            foreach( f; iniFile[i]["sourcefiles"].split(",") )
                dFiles ~= dirEntry(f);
        }

        if( verbosity > 1 )
            writeln( dFiles );

        foreach( d; dFiles ){//todo use  iniFile["filter"]; use time to build, rebuild or do nothing

            bool needToBuild        = false;
            string generatedObjFile = buildNormalizedPath( iniFile[i]["builddir"], "objects", stripExtension(d.name) ~ ".o");

            if( exists( generatedObjFile ) ){
                DirEntry tmp = dirEntry( generatedObjFile );
                if( d.timeLastModified < tmp.timeLastModified )
                    needToBuild = true;
            }
            else
                needToBuild = true;

            if( needToBuild ){
                string cmd = "%s %s".format( iniFile[i]["compiler"], iniFile[i]["dflags"] );  // add compiler and his D flags

                foreach( dir; iniFile[i]["importsdir"].split(","))                            // add dir to include
                    cmd ~= " -I%s".format( dir );
                cmd ~= " -I%s".format( iniFile[i]["sourcedir"] );

                if( iniFile[i]["type"] == "shared" ){
                    cmd ~= ( iniFile[i]["dl"] == "" ) ? " " ~ iniFile[i]["fpic"]: iniFile[i]["linker"] ~ iniFile[i]["dl"] ~ " " ~ iniFile[i]["fpic"];
                }
                else if( iniFile[i]["type"] == "static" ){
                    cmd ~= ( iniFile[i]["dl"] == "" ) ? "" : " " ~ iniFile[i]["linker"] ~ iniFile["dl"];
                }
                cmd ~= " -c %s %s%s %s%s %s%s".format (
                                                        d.name,
                                                        iniFile[i]["output"],
                                                        buildNormalizedPath( iniFile[i]["builddir"], "objects",stripExtension(d.name) ~ ".o"),
                                                        iniFile[i]["docFile"],
                                                        buildNormalizedPath( iniFile[i]["builddir"], "doc", stripExtension(d.name) ~ ".html"),
                                                        iniFile[i]["headerFile"],
                                                        buildNormalizedPath( iniFile[i]["builddir"], "imports", stripExtension(d.name) ~ ".di")
                                                    );

                if( verbosity > 1 )
                    writeln( cmd );

                system( cmd );
            }
        }
        oFiles      = array(map!(a => a = dirEntry( buildNormalizedPath( iniFile[i]["builddir"], "objects", stripExtension(a.name) ~ ".o")))(dFiles));
        docFiles    = array(map!(a => a = dirEntry( buildNormalizedPath( iniFile[i]["builddir"], "doc", stripExtension(a.name) ~ ".html")))(dFiles));
        diFiles     = array(map!(a => a = dirEntry( buildNormalizedPath( iniFile[i]["builddir"], "imports", stripExtension(a.name) ~ ".di")))(dFiles));

        auto oFilesName     = map!(a => a.name)(oFiles);
        auto docFilesName   = map!(a => a.name)(docFiles);
        auto diFilesName    = map!(a => a.name)(diFiles);

        foreach( objects; array(oFilesName) )
            objectsSection[ baseName(objects) ] = objects;
        foreach( docs; array(docFilesName) )
            documentationsSection[ baseName(docs) ] = docs;
        foreach( di; array(diFilesName) )
            importsSection[ baseName(di) ] = di;

        string output       = "";
        string linkingCmd   = "";

        switch(iniFile[i]["type"]){
            case("shared"):
                if( !exists("lib") )
                     mkdir( "lib" );
                else
                    assert( isDir("lib") , "A file \"lib\" exist already then it is impossible to create a directory with same name" );
                output = buildNormalizedPath( iniFile[i]["builddir"],"lib", "lib" ~ outFile ~  iniFile[i]["dynamicLibExt"] ~ "." ~ iniFile[i]["version"] );
                linkingCmd = "%s %s %s %s%s".format( iniFile[i]["compiler"], iniFile[i]["soname"], array(oFilesName).join( " " ), iniFile[i]["output"], output);
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
                linkingCmd = "ar rcs %s %s".format( output, array(oFilesName).join( " " ) );
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
                linkingCmd = "%s %s %s".format( iniFile[i]["compiler"], array(oFilesName).join( " " ), iniFile[i]["output"], output );
                if( verbosity > 1 )
                    writeln( linkingCmd );
                system( linkingCmd );
                break;
            default:
                throw new Exception("Unknown build type %s".format( iniFile[i]["type"] ));
        }

        currentSection[ baseName(output) ] = output;
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
    if( verbosity > 0 )
        writeln("→ Cleaning the project");

    IniFile iniFile     = dbuilder.ini.open( buildCacheFile );                          // Load cache file
    const size_t max    = iniFile.length;
    //~ defaultPoolThreads( to!uint(iniFile["jobs"]) );                                 // Set number of jobs to execute in same time

    for( size_t i = 0; i < max; i++ ){
        foreach( string value; iniFile[i].get("objects").values ~ iniFile[i].get("documentations").values ~ iniFile[i].get("imports").values ){
            if( exists( value ) ){
                if( verbosity > 1 )
                    writeln( "\t Removing file: " ~ value );
                remove( value );
            }
        }

        if( exists(  iniFile[i]["out"] ) ){
            if( verbosity > 1 )
                writeln( "\t Removing file: " ~ iniFile[i]["out"] );
            remove( iniFile[i]["out"] );
        }
    }


}

void installer( string[] args ){
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

                string dest = currentBuild["out"].replace( buildlibDir, libdirProject );

                if( verbosity > 1 )
                    writeln( "Copy ",  currentBuild["out"], " to ", dest);

                copy(currentBuild["out"], dest);
                break;
            case("static"):
                if( !exists( libdirProject ) )
                    mkdirRecurse( libdirProject );

                string dest =currentBuild["out"].replace( buildlibDir, libdirProject );

                if( verbosity > 1 )
                    writeln( "Copy ",  currentBuild["out"], " to ", dest);

                copy(currentBuild["out"], dest);
                break;
            case("executable"):
                if( !exists( bindirProject ) )
                    mkdirRecurse( bindirProject );

                string dest = currentBuild["out"].replace( buildbinDir, bindirProject );

                if( verbosity > 1 )
                    writeln( "Copy ",  currentBuild["out"], " to ", dest);

                copy(currentBuild["out"], dest);
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
       writeln( "Warning: no config file found in cache, ensure you have run previously the target configure" );

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
