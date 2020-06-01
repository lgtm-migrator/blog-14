#!/bin/sh

# Cache folder
CACHEDIR=/tmp/hexo-blog
mkdir -p $CACHEDIR

RECENT_COMMENTS=$(wget -O- https://lantian.disqus.com/recent_comments_widget.js\?num_items\=10\&hide_mods\=0\&hide_avatars\=1\&excerpt_length\=100)
# Remove delimiters and fixed strings
RECENT_COMMENTS=$(echo "$RECENT_COMMENTS" | sed "s/Lan Tian @ Blog//g;s/https:\/\/lantian.pub//g")
RECENT_COMMENTS=$(echo "$RECENT_COMMENTS" | sed "s/ | //g;s/ - //g;s/&nbsp\;&middot\;&nbsp\;//g")
# NodeJS preprocessing
RECENT_COMMENTS=$(echo "$RECENT_COMMENTS" | sed "s/document.write/process.stdout.write/g")
RECENT_COMMENTS=$(echo "$RECENT_COMMENTS" | node)
echo ${RECENT_COMMENTS#*<\/style>} > themes/lantian/layout/_partial/disqus-recent.ejs

# Font Awesome update
cp node_modules/@fortawesome/fontawesome-free/webfonts/* themes/lantian/source/assets/fonts/

# Regenerate everything
rm -rf public .deploy_git
node_modules/hexo/bin/hexo generate

# Hexo deploy takes care of git, and baidu_url_submit
node_modules/hexo/bin/hexo deploy

# # Deploy to local IPFS cluster
# IPFS_HASH=$(ipfs-cluster-ctl add -r -Q public)
# curl -H 'X-Api-Key: ***REMOVED***' -X PATCH "http://172.18.0.1:8081/api/v1/servers/localhost/zones/lantian.pub" --data '{"rrsets": [{"name": "ipfs.lantian.pub.","records": [{"content": "\"dnslink=/ipfs/${IPFS_HASH}\"","disabled": false}],"ttl": 600,"type": "TXT","changetype": "REPLACE"},{"name": "_dnslink.ipfs.lantian.pub.","records": [{"content": "\"dnslink=/ipfs/${IPFS_HASH}\"","disabled": false}],"ttl": 600,"type": "TXT","changetype": "REPLACE"}]}'

# Deploy to IPFS pinning services
export IPFS_DEPLOY_PINATA__API_KEY=***REMOVED***
export IPFS_DEPLOY_PINATA__SECRET_API_KEY=***REMOVED***
export IPFS_DEPLOY_CLOUDFLARE__API_EMAIL=b980120@hotmail.com
export IPFS_DEPLOY_CLOUDFLARE__API_KEY=f832baa082df741c9ef32a4c1fa829eb0b95e
export IPFS_DEPLOY_CLOUDFLARE__ZONE=xuyh0120.win
export IPFS_DEPLOY_CLOUDFLARE__RECORD=_dnslink.ipfs.xuyh0120.win
node_modules/ipfs-deploy/bin/ipfs-deploy.js public/ -p pinata -d cloudflare -C -O

# Pinata: obtain last pinned hash
PINATA_LAST_HASH=$(curl -H 'pinata_api_key: ***REMOVED***' -H 'pinata_secret_api_key: ***REMOVED***' "https://api.pinata.cloud/data/pinList?status=pinned&metadata[name]=_dnslink.ipfs.xuyh0120.win" | jq -r ".rows[1].ipfs_pin_hash")
# Pinata: remove last hash
curl -X DELETE -H 'pinata_api_key: ***REMOVED***' -H 'pinata_secret_api_key: ***REMOVED***' -H 'Content-Type: application/json' "https://api.pinata.cloud/pinning/unpin/$PINATA_LAST_HASH"

# Compress to gzip, brotli, zstd and webp only for my own site system
# Useless on other hosts, e.g. GitHub Pages
echo Preparing parallel jobs...
echo > parallel_jobs.lst
for FILE in $(find public -type f \( -name "*.html" -or -name "*.css" -or -name "*.js" -or -name "*.ttf" -or -name "*.atom" -or -name "*.stl" -or -name "*.xml" -or -name "*.svg" -or -name "*.eot" -or -name "*.json" -or -name "*.txt" \)); do
    if [ ! -f $FILE.gz ]; then
        echo gzip -9 -k -f $FILE >> parallel_jobs.lst
    fi
    if [ ! -f $FILE.br ]; then
        echo brotli -9 -k -f $FILE >> parallel_jobs.lst
    fi
    if [ ! -f $FILE.zst ]; then
        echo "sh -c \"zstd --no-progress -19 -k -f $FILE 2>/dev/null\"" >> parallel_jobs.lst
    fi
done
for FILE in $(find public -type f \( -name "*.gif" -or -name "*.jpg" -or -name "*.png" \)); do
    if [ ! -f $FILE.webp ]; then
        SHA256=$(sha256sum $FILE | cut -d' ' -f1)
        if [ -f $CACHEDIR/$SHA256.webp ]; then
            cp $CACHEDIR/$SHA256.webp $FILE.webp
        else
            echo "sh -c \"convert -quality 100 $FILE $FILE.webp && cp $FILE.webp $CACHEDIR/$SHA256.webp\"" >> parallel_jobs.lst
        fi
    fi
done
echo Executing parallel jobs...
parallel -j$(nproc) < parallel_jobs.lst

# Deploy to my site system
python -c "import fcntl; fcntl.fcntl(1, fcntl.F_SETFL, 0)"
ansible website -m synchronize -a "src=public/ dest=/srv/www/lantian.pub/"

# Index new posts on Algolia
node_modules/hexo/bin/hexo algolia
