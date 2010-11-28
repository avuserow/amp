/* Copyright (C) 2003 Scott Wheeler <wheeler@kde.org>
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/* Copyright (C) 2009-2010 the Acoustics development team.
 * We only made small changes. Many thanks to the taglib developers.
 *
 * See https://github.com/avuserow/amp and
 * https://github.com/avuserow/taglib
 * */

#include <iostream>
#include <stdio.h>

#include <fileref.h>
#include <tag.h>

using namespace std;

int main(int argc, char *argv[])
{
  for(int i = 1; i < argc; i++) {

    cout << "path:" << argv[i] << endl;

    TagLib::FileRef f(argv[i]);

    if(!f.isNull() && f.tag()) {

      TagLib::Tag *tag = f.tag();

      cout << "title:" << (tag->title()).toCString(true)   << endl;
      cout << "artist:" << (tag->artist()).toCString(true) << endl;
      cout << "album:" << (tag->album()).toCString(true)   << endl;
      cout << "albumartist:" << (tag->albumArtist()).toCString(true) << endl;
      cout << "track:" << tag->track() << endl;
      cout << "disc:"  << tag->cdNr() << endl;
    }

    if(!f.isNull() && f.audioProperties()) {

      TagLib::AudioProperties *properties = f.audioProperties();

      cout << "bitrate:" << properties->bitrate() << endl;
      cout << "length:" << properties->length()  << endl;
    }
  if(i!=argc-1)
    cout << "---" << endl;
  }
  return 0;
}
