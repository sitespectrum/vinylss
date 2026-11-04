# Build context: backend/
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

COPY src/Vinylss.Api/Vinylss.Api.csproj src/Vinylss.Api/
RUN dotnet restore src/Vinylss.Api/Vinylss.Api.csproj

COPY src/Vinylss.Api/ src/Vinylss.Api/
RUN dotnet publish src/Vinylss.Api/Vinylss.Api.csproj -c Release -o /app --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:10.0
WORKDIR /app

# SQLite database lives on a volume; owned by the image's non-root "app" user.
RUN mkdir /data && chown "$APP_UID" /data
VOLUME /data

ENV ASPNETCORE_HTTP_PORTS=8080 \
    ConnectionStrings__Default="Data Source=/data/vinylss.db"
EXPOSE 8080

COPY --from=build /app .
USER $APP_UID
ENTRYPOINT ["dotnet", "Vinylss.Api.dll"]
