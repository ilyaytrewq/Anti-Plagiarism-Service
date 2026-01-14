# Серверный код
oapi-codegen -generate chi-server,types -package api \
  -o ./api-gateway/internal/api/generated/generated.go \
  ./api-files/openapi.yaml

oapi-codegen -generate chi-server,types -package api \
  -o ./file-analisys/internal/api/generated/generated.go \
  ./api-files/file-analisys.yaml

oapi-codegen -generate chi-server,types -package api \
  -o ./file-storing/internal/api/generated/generated.go \
  ./api-files/file-storing.yaml

oapi-codegen -generate chi-server,types -package api \
  -o ./embedding-service/internal/api/generated/generated.go \
  ./api-files/embedding-service.yaml

# Клиентский код API Gateway
oapi-codegen -generate client,types -package filestoring \
  -o ./api-gateway/internal/clients/filestoring/client.go \
  ./api-files/file-storing.yaml

oapi-codegen -generate client,types -package fileanalysis \
  -o ./api-gateway/internal/clients/fileanalysis/client.go \
  ./api-files/file-analisys.yaml

oapi-codegen -generate client,types -package embedding \
  -o ./file-analisys/internal/clients/embedding/client.go \
  ./api-files/embedding-service.yaml

oapi-codegen -generate client,types -package filestoring \
  -o ./file-analisys/internal/clients/filestoring/client.go \
  ./api-files/file-storing.yaml