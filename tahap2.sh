export PROJECT_ID=$(gcloud config get-value project)
export REGION="us-west1"
export ZONE="us-west1-a"
cd ~/sample-app

echo "🛠️ 1. Deploy Versi 1.0 (Dev & Prod)..."
# DEV V1.0
git checkout dev
sed -i 's/<version>/v1.0/g' cloudbuild-dev.yaml
IMAGE_NAME=$(grep -o "${REGION}-docker.pkg.dev/${PROJECT_ID}/my-repository/[^:]*" cloudbuild-dev.yaml | head -n 1)
sed -i "s|<todo>|${IMAGE_NAME}:v1.0|g" dev/deployment.yaml
git add .
git commit -m "Deploy dev v1.0"
git push origin dev

# MASTER V1.0
git checkout master
sed -i 's/<version>/v1.0/g' cloudbuild.yaml
sed -i "s|<todo>|${IMAGE_NAME}:v1.0|g" prod/deployment.yaml
git add .
git commit -m "Deploy prod v1.0"
git push origin master

echo "⏳ Menunggu 100 detik agar Cloud Build menyelesaikan build v1.0 (Bisa disambi minum kopi santai)..."
sleep 100

echo "🛠️ 2. Mengekspos Layanan LoadBalancer (Task 4)..."
gcloud container clusters get-credentials hello-cluster --zone=$ZONE
kubectl expose deployment development-deployment --namespace=dev --name=dev-deployment-service --type=LoadBalancer --port=8080 --target-port=8080 || true
kubectl expose deployment production-deployment --namespace=prod --name=prod-deployment-service --type=LoadBalancer --port=8080 --target-port=8080 || true

echo "🛠️ 3. Modifikasi kode Go ke Versi 2.0 (Menambahkan handler /red)..."
cat << 'EOF' > main.go
package main

import (
	"image"
	"image/color"
	"image/draw"
	"image/png"
	"net/http"
)

func main() {
	http.HandleFunc("/blue", blueHandler)
	http.HandleFunc("/red", redHandler)
	http.ListenAndServe(":8080", nil)
}

func blueHandler(w http.ResponseWriter, r *http.Request) {
	img := image.NewRGBA(image.Rect(0, 0, 100, 100))
	draw.Draw(img, img.Bounds(), &image.Uniform{color.RGBA{0, 0, 255, 255}}, image.ZP, draw.Src)
	w.Header().Set("Content-Type", "image/png")
	png.Encode(w, img)
}

func redHandler(w http.ResponseWriter, r *http.Request) {
	img := image.NewRGBA(image.Rect(0, 0, 100, 100))
	draw.Draw(img, img.Bounds(), &image.Uniform{color.RGBA{255, 0, 0, 255}}, image.ZP, draw.Src)
	w.Header().Set("Content-Type", "image/png")
	png.Encode(w, img)
}
EOF

echo "🛠️ 4. Deploy Versi 2.0 (Dev & Prod)..."
# DEV V2.0
git checkout dev
cp ../main.go . || true
sed -i 's/v1.0/v2.0/g' cloudbuild-dev.yaml
sed -i 's/v1.0/v2.0/g' dev/deployment.yaml
git add .
git commit -m "Deploy dev v2.0"
git push origin dev

# MASTER V2.0
git checkout master
git checkout dev -- main.go
sed -i 's/v1.0/v2.0/g' cloudbuild.yaml
sed -i 's/v1.0/v2.0/g' prod/deployment.yaml
git add .
git commit -m "Deploy prod v2.0"
git push origin master

echo "⏳ Menunggu 100 detik agar Cloud Build menyelesaikan build v2.0..."
sleep 100

echo "🛠️ 5. Rollback Production Deployment ke Versi 1.0 (Task 6)..."
CONTAINER=$(kubectl get deployment production-deployment -n prod -o=jsonpath='{.spec.template.spec.containers[0].name}')
kubectl set image deployment/production-deployment ${CONTAINER}=${IMAGE_NAME}:v1.0 --namespace=prod

echo "🎉 SEMUA TASK SELESAI! Silakan sikat semua tombol Check my progress yang tersisa! 🎉"
