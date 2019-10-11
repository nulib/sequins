ExUnit.start(capture_log: true)
Mox.defmock(Meadow.ExAwsHttpMock, for: ExAws.Request.HttpClient)
