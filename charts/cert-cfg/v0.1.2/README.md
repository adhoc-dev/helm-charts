# Platform configurations

## Cert Issuer configurations

Files:

* prod_issuer.yaml
* staging_issuer.yaml

## nginx configs

Configuration [+info](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/configmap/)  
Custom Configuration [+info](https://kubernetes.github.io/ingress-nginx/examples/customization/custom-configuration/)  
Configmap Resource [+info](https://docs.nginx.com/nginx-ingress-controller/configuration/global-configuration/configmap-resource/)  
x-forwarded [+info](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/#x-forwarded-prefix-header)  

Files:

* nginx_configMap.yaml

## Providers

### Cloudflare

API Token [+info](https://cert-manager.io/docs/configuration/acme/dns01/cloudflare/)

Permissions: 
- Zone - DNS - Edit
- Zone - Zone - Read

Zone Resources:
- Include - All Zones
