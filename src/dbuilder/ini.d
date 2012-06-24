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
 * Implements functionality to read ini files from a input range.
 *
 * Copyright: Copyright Jonathan MERCIER  2012-.
 *
 * License:   GPLv3+
 *
 * Authors:   Jonathan MERCIER aka bioinfornatics
 *
 * Source: dbuilder/ini.d
 */
module dbuilder.ini;

import std.string;
import std.array;
import std.stdio;
import std.exception;


/**
 * parse is a method for parse a INI file or config file.
 *
 * Returns: A Section object with all information
 *
 * Examples:
 * --------------------
 * import dscience.parser.ini;
 * string filePath  = "~/myGreatSetup.conf";
 * IniFile sections = dbuilder.ini.open( filePath );
 * --------------------
 */

IniFile open( string filePath ){
    Section         root            = new Section("root", 0);           // root section
    Section         currentSection  = root;                             // reference to current section
    Section         nextSection     = null;
    File            iniFile         = File( filePath, "r" );
    foreach( line; iniFile.byLine() ){                                  // read line by line
        try{
            line = line.stripLeft().stripRight();
            if( line == "" || line[0] == ';' ){                         // empty line line or comment line
                continue;
            }
            else if( line[0] == '[' ){                                  // section start
                nextSection = getSection( cast(string)line );           // get newest section
                if( currentSection.level < nextSection.level ){         // currentSection.level < nextSection.level
                    currentSection.addChild( nextSection );             // add a child to current section
                    currentSection = nextSection;                       // now current section go to next one
                }
                else if( currentSection.level == nextSection.level ){   // currentSection.level = nextSection.level
                    currentSection = currentSection.rewind( currentSection.parent.level );
                    currentSection.addChild( nextSection );
                    currentSection = nextSection;
                }
                else{                                                   // currentSection.level > nextSection.level
                    currentSection = currentSection.rewind( nextSection.level - 1);
                    currentSection.addChild( nextSection );
                    currentSection = nextSection;
                }
            }
            else{                                                       // read information corresponding to a section
                string[] words = split(cast(string)line, "=");          // get key / value peer
                foreach( ref string word; words )
                    word = word.stripRight().stripLeft();               // remove space, before and after word
                if( words.length == 2 )
                    currentSection[ words[0] ] = words[1];
                else if( words.length == 1 )
                    currentSection[ words[0] ];
                else
                    currentSection[ words[0] ] = words[1 .. $].join("=");
            }
        }
        catch(Exception e){
            writeln( "Error: config file seem to not not follow specification!" );
            writeln( e.msg );
            writefln( "Line: %s", line );
        }
    }
    root.shrink;
    return root;
}

alias Section IniFile;
class Section{
    private:
        string          _name;
        Section         _parent;
        Section[]       _childs;
        size_t          _level;
        size_t          _numberOfChild;
        string[string]  _dict;

    public:
        /**
         * Constructor for a Section object
         *
         * Params: name level
         */
        this(string name, size_t level){
            _name           = name;
            _level          = level;
            _childs         = [];
            _numberOfChild  = 0;
            _dict           = null;
        }

        /**
         * Constructor for copy Section object
         *
         * Params: name parent level childs numberOfChild dict
         */
        this( string name, Section parent, size_t level, Section[] childs, size_t numberOfChild, string[string] dict ){
            _name           = name;
            _level          = level;
            _childs.length  = childs.length;
            foreach(size_t index, child; childs)
                this._childs[index] = child.dup;
            _numberOfChild  = numberOfChild;
            _dict           = dict;
        }

        /**
         * addChild is used for add a subsection to current section
         *
         * Params: Section
         */
        void addChild( ref Section section ){
            if( _numberOfChild >= _childs.length )
                _childs.length      = _childs.length + 5;        // resize +5 for not resize 1 by 1
            section.parent          = this;
            _childs[_numberOfChild] = section;
            _numberOfChild++;
        }

        /**
         * Resize object to same size as data contained by the object
         */
        @property void shrink(){
            _childs.length = _numberOfChild;
            foreach( child; _childs )
                child.shrink;
        }

        /**
         * get return the subsection where name equal name given
         *
         * Params: name
         *
         * Retuns: Section, null if not found
         */
        Section get( string name ){
            Section section     = null;
            bool    isSearching = true;
            size_t  index       = 0;
            while( isSearching ){
                if( index >= _numberOfChild )
                    isSearching = false;
                else if( _childs[index].name == name ){
                    isSearching = false;
                    section = _childs[index].dup;
                }
                index++;
            }
            return section;
        }


        /**
         * opIndex
         * Acces to a value in current Section by giving his key
         */
        string opIndex( string key ){
            enforce( key in  _dict, "Unknown sub-section : %s".format(key) );
            return _dict[key];
        }

        /**
         * opIndex
         * Acces to a sub Section by giving his index position
         */
        Section opIndex( size_t index ){
            return _childs[index];
        }

        /**
         * opIndexAssign
         * Append a pair key/value in current Section
         */
        void opIndexAssign( string  value, string key ){
            _dict[key.idup] = value.idup;
        }

        /**
         * rewind is used for come back to parent at level given
         *
         * Params: level
         */
        Section rewind( size_t levelToGo ){                            // rewind to parent level x
            Section section     = null;
            if( _level == levelToGo)
                section = this;
            else if( _level >= levelToGo)
                section = _parent.rewind( levelToGo );
            else
                throw new Exception("You try to go back when current section is lower where level you want to go!");
            return section;
        }

        /**
         * toString used for print current object state
         *
         * Returns: a string
         */
        override string toString(){
            string content = "";
            string start   = "";
            string end     = "";
            if( _name != "root" ){
                foreach(i; 0 .. _level){
                    start   ~= "[";
                    end     ~= "]";
                }
                content ~= start ~ _name ~ end ~ "\n"; // [section1] ... [[section2]]
                foreach( key, value; _dict )
                    content ~= "%s=%s\n".format( key, value );
            }
            foreach(child; _childs){
                if( child !is null )
                    content ~= child.toString();
            }
            return content.idup;
        }

        @property Section dup(){
            return new Section( this._name, this.parent, this._level, this._childs, this._numberOfChild, this._dict );
        }

        @property string name(){
            return _name.idup;
        }

        @property Section parent(){
            return _parent;
        }

        @property Section parent(Section section){
            return _parent = section;
        }

        @property Section[] childs(){
            return _childs.dup;
        }

        @property size_t level(){
            return _level;
        }

        @property size_t length(){
            return _numberOfChild;
        }

        @property string[] keys(){
            return _dict.keys;
        }

        @property string[] values(){
            return _dict.values;
        }

        @property void rehash(){
            _dict.rehash;
            foreach(child; _childs)
                child.rehash;
        }

        @property bool empty(){
            return _numberOfChild == 0;
        }

        @property ref Section front(){
            return childs[0];
        }

        @property ref Section back(){
            return  _childs[$ - 1];
        }

        void popFront(){
            _childs = _childs[1..$];
            _numberOfChild--;
        }

        void popBack(){
            _childs = _childs[0 .. $ - 1];
            _numberOfChild--;
        }

        ref Section save(){
            return this;
        }

        bool opBinaryRight(string op : "in")(string value) {
            bool result = false;
            if( _dict !is null )
                result = (value in _dict) ? true : false;
            return result;
        }
}


/**
 * getSection create a Section line with corresponding line
 *
 * Returns: Section object
 *
 * Examples:
 * --------------------
 * string line      = "[default]";
 * Section section  = getSection( line );
 * --------------------
 */
Section getSection( string lineSection ){
    size_t  level           = 0;
    size_t  position        = 0;
    string  name            = "";
    // get level
    while( lineSection[level] == '[' ){
        level++;
    }
    position = level;
    // get section name
    while( lineSection[position] != ']' ){
        name ~= lineSection[position];
        position++;
    }
    return new Section(name, level);
}
