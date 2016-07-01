defmodule EvercamMedia.Router do
  use EvercamMedia.Web, :router

  pipeline :browser do
    plug :accepts, ["html", "json", "jpg"]
    plug :fetch_session
    plug :fetch_flash
    plug CORSPlug, origin: ["*"]
  end

  pipeline :api do
    plug :accepts, ["json", "jpg"]
    plug CORSPlug, origin: ["*"]
  end

  pipeline :auth do
    plug EvercamMedia.AuthenticationPlug
  end

  pipeline :onvif do
    plug EvercamMedia.ONVIFAccessPlug
  end

  scope "/", EvercamMedia do
    pipe_through :browser

    get "/", PageController, :index

    get "/live/:token/index.m3u8", StreamController, :hls
    get "/live/:token/:filename", StreamController, :ts
    get "/on_play", StreamController, :rtmp
  end

  scope "/v1", EvercamMedia do
    pipe_through :api

    get "/cameras/port-check", CameraController, :port_check
    post "/cameras/test", SnapshotController, :test
    get "/cameras/:id/recordings/snapshots/data/:snapshot_id", SnapshotController, :data

    get "/cameras/:id/touch", CameraController, :touch
    get "/cameras/:id/thumbnail/:timestamp", CameraController, :thumbnail

    get "/models/:id", ModelController, :show

    get "/vendors/:id", VendorController, :show
    get "/vendors", VendorController, :index

    scope "/" do
      pipe_through :auth

      get "/users/:id", UserController, :get
      delete "/users/:id", UserController, :delete

      get "/cameras", CameraController, :index
      get "/cameras.json", CameraController, :index
      get "/cameras/:id", CameraController, :show
      patch "/cameras/:id", CameraController, :update
      options "/cameras/:id", CameraController, :nothing
      put "/cameras/:id", CameraController, :transfer
      options "/cameras/:id", CameraController, :nothing
      get "/cameras/:id/thumbnail", SnapshotController, :thumbnail
      get "/cameras/:id/live/snapshot", SnapshotController, :live
      get "/cameras/:id/live/snapshot.jpg", SnapshotController, :live
      get "/cameras/:id/recordings/snapshots", SnapshotController, :index
      options "/cameras/:id/recordings/snapshots", SnapshotController, :nothing
      get "/cameras/:id/recordings/snapshots/:timestamp", SnapshotController, :show
      options "/cameras/:id/recordings/snapshots/:timestamp", SnapshotController, :nothing
      post "/cameras/:id/recordings/snapshots", SnapshotController, :create
      get "/cameras/:id/recordings/snapshots/:year/:month/:day", SnapshotController, :day
      options "/cameras/:id/recordings/snapshots/:year/:month/:day", SnapshotController, :nothing
      get "/cameras/:id/recordings/snapshots/:year/:month/:day/hours", SnapshotController, :hours
      options "/cameras/:id/recordings/snapshots/:year/:month/:day/hours", SnapshotController, :nothing
      get "/cameras/:id/recordings/snapshots/:year/:month/:day/:hour", SnapshotController, :hour
      options "/cameras/:id/recordings/snapshots/:year/:month/:day/:hour", SnapshotController, :nothing
      get "/cameras/:id/logs", LogController, :show
      get "/cameras/:id/apps/cloud-recording", CloudRecordingController, :show
      post "/cameras/:id/apps/cloud-recording", CloudRecordingController, :create
      get "/cameras/:id/shares", CameraShareController, :show
      post "/cameras/:id/shares", CameraShareController, :create
      patch "/cameras/:id/shares", CameraShareController, :update
      delete "/cameras/:id/shares", CameraShareController, :delete
      get "/cameras/:id/shares/requests", CameraShareRequestController, :show
      patch "/cameras/:id/shares/requests", CameraShareRequestController, :update
      delete "/cameras/:id/shares/requests", CameraShareRequestController, :cancel

      get "/cameras/:id/archives", ArchiveController, :index
      get "/cameras/:id/archives/:archive_id", ArchiveController, :show
      delete "/cameras/:id/archives/:archive_id", ArchiveController, :delete
      options "/cameras/:id/archives/:archive_id", ArchiveController, :nothing
    end

    scope "/" do
      pipe_through :onvif

      get "/cameras/:id/ptz/status", ONVIFPTZController, :status
      get "/cameras/:id/ptz/presets", ONVIFPTZController, :presets
      get "/cameras/:id/ptz/nodes", ONVIFPTZController, :nodes
      get "/cameras/:id/ptz/configurations", ONVIFPTZController, :configurations
      post "/cameras/:id/ptz/home", ONVIFPTZController, :home
      post "/cameras/:id/ptz/home/set", ONVIFPTZController, :sethome
      post "/cameras/:id/ptz/presets/:preset_token", ONVIFPTZController, :setpreset
      post "/cameras/:id/ptz/presets/create/:preset_name", ONVIFPTZController, :createpreset
      post "/cameras/:id/ptz/presets/go/:preset_token", ONVIFPTZController, :gotopreset
      post "/cameras/:id/ptz/continuous/start/:direction", ONVIFPTZController, :continuousmove
      post "/cameras/:id/ptz/continuous/zoom/:mode", ONVIFPTZController, :continuouszoom
      post "/cameras/:id/ptz/continuous/stop", ONVIFPTZController, :stop
      post "/cameras/:id/ptz/relative", ONVIFPTZController, :relativemove

      get "/onvif/v20/:service/:operation", ONVIFController, :invoke
    end
  end
end
