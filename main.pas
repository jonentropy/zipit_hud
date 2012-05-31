{
 * Copyright (c) 2012, Tristan Linnell <tris@canthack.org>
 *
 * Permission to use, copy, modify, and/or distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
}

// zipit_hud hgd hud for zipit z2, written in Lazarus/Freepascal
// main.pas - GUI
// Depends on having the current tree of hgdc-x checked out to the
// same directory.

unit main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
  LCLType, ExtCtrls, XMLPropStorage, HGDClient, LastFM;

type

  TGUIState = (gsHUD, gsSettings, gsAbout);

  { TfrmMain }

  TfrmMain = class(TForm)
    edtHost: TEdit;
    edtPort: TEdit;
    imNowPlaying: TImage;
    Label1: TLabel;
    lblHost: TLabel;
    lblPort: TLabel;
    lblTitle: TLabel;
    lblAlbum: TLabel;
    lblUser: TLabel;
    lblArtist: TLabel;
    tmrPlaylist: TTimer;
    XMLPropStorage1: TXMLPropStorage;
    procedure FormDestroy(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormShow(Sender: TObject);
    procedure tmrPlaylistTimer(Sender: TObject);
  private
    FClient: THGDClient;
    FLastFM: TLastFM;
    FCurrentlyDisplayedArtwork: string;
    FArtworkAttempts: integer;
    procedure ApplyChanges;
    procedure SetGUIState(state: TGUIState);
    { private declarations }
  public
    { public declarations }
  end; 

var
  frmMain: TfrmMain;

const
  MAX_ARTWORK_ATTEMPTS = 3;

implementation

{$R *.lfm}

{ TfrmMain }

procedure TfrmMain.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Key = VK_ESCAPE then
    Close();
  if Key = VK_RETURN then
    SetGUIState(gsHUD);

  if ssCtrl in Shift then
  begin
    if Key = VK_S then
      SetGUIState(gsSettings)
    else if Key = VK_A then
      SetGUIState(gsAbout)
    else if Key = VK_H then
      SetGUIState(gsHUD);
  end;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  FLastFM.Free();
  FClient.Free();
end;

procedure TfrmMain.FormShow(Sender: TObject);
begin
  FCurrentlyDisplayedArtwork := '';
  FArtworkAttempts := 0;

  FClient := THGDClient.Create(edtHost.Text, edtPort.Text, '', '', False, False);
  FLastFM := TLastFM.Create('', GetAppConfigDirUTF8(False), False);

  SetGUIState(gsHUD);
end;

procedure TfrmMain.SetGUIState(state: TGUIState);
begin
  lblAlbum.Visible := state = gsHUD;
  lblTitle.Visible := state = gsHUD;
  lblUser.Visible := state = gsHUD;
  lblArtist.Visible := state = gsHUD;
  imNowPlaying.Visible := state = gsHUD;

  edtHost.Visible := state = gsSettings;
  edtPort.Visible := state = gsSettings;
  lblHost.Visible := state = gsSettings;
  lblPort.Visible := state = gsSettings;
  if state = gsSettings then
    edtHost.SetFocus();

  if state = gsHUD then
    ApplyChanges();
end;

procedure TfrmMain.ApplyChanges;
begin
  tmrPlaylist.Enabled := False;

  XMLPropStorage1.Save();

  if Assigned(FClient) then
  begin
    FClient.HostAddress := edtHost.Text;
    FClient.HostPort := edtPort.Text;

    FClient.ApplyChanges();
  end;

  tmrPlaylist.Enabled := True;
  tmrPlayListTimer(Self);
end;

procedure TfrmMain.tmrPlaylistTimer(Sender: TObject);
var
  NowPlayingSong: TTrackInfo;
begin
  tmrPlaylist.Enabled := False;

  if Assigned(FClient) and (FClient.State >= hsConnected) then
  begin
    //Display now playing info
    if FClient.GetNowPlaying(NowPlayingSong) then
    begin
      //A song is currently playing

      if NowPlayingSong.Title <> '' then
        lblTitle.Caption := NowPlayingSong.Title
      else
        lblTitle.Caption := NowPlayingSong.Filename;

      lblArtist.Caption := NowPlayingSong.Artist;
      lblAlbum.Caption := NowPlayingSong.Album;
      lblUser.Caption := 'Queued by ' + NowPlayingSong.User;

      if (NowPlayingSong.Artist <> '') and (NowPlayingSong.Album <> '') then
      begin
        if ((NowPlayingSong.Artist + ':' + NowPlayingSong.Album) <>
          FCurrentlyDisplayedArtwork) then
        begin
          //Playing track has changed, get artwork
          imNowPlaying.Visible := True;

          if FLastFM.GetAlbumArt(NowPlayingSong.Artist, NowPlayingSong.Album,
            szMedium, imNowPlaying) then
          begin
            FCurrentlyDisplayedArtwork := NowPlayingSong.Artist + ':' +
              NowPlayingSong.Album;

            FArtworkAttempts := 0;
          end
          else
          begin
            //Couldn't get artwork, so hide it
            Inc(FArtworkAttempts);
            imNowPlaying.Visible := False;
          end;

          if (FArtworkAttempts = MAX_ARTWORK_ATTEMPTS) then
          begin
            FCurrentlyDisplayedArtwork := NowPlayingSong.Artist + ':' +
              NowPlayingSong.Album;

            FArtworkAttempts := 0;
          end;
        end;
      end
      else
      begin
        //No album information to get art with
        imNowPlaying.Visible := False;
      end;
    end
    else
    begin
      //Nothing playing
      lblTitle.Caption := 'Nothing Playing';
      lblArtist.Caption := '';
      lblAlbum.Caption := '';
      lblUser.Caption := '';
      FCurrentlyDisplayedArtwork := '';
      imNowPlaying.Picture.Clear();
      imNowPlaying.Visible := False;
    end;
  end
  else
  begin
    lblTitle.Caption := 'Problem connecting';
    lblArtist.Caption := '';
    lblAlbum.Caption := '';
    lblUser.Caption := '';
    FCurrentlyDisplayedArtwork := '';
    imNowPlaying.Picture.Clear();
    imNowPlaying.Visible := False;
  end;

  tmrPlaylist.Enabled := True;
end;

end.
