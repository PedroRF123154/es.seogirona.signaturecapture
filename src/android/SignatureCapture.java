package es.seogirona.signaturecapture;

import android.Manifest;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Path;
import android.os.Environment;
import android.util.DisplayMetrics;
import android.util.Log;
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.View;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.ImageView;
import androidx.annotation.NonNull;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaActivity;
import org.json.JSONArray;
import org.json.JSONObject;

import java.io.File;
import java.io.FileOutputStream;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class SignatureCapture extends CordovaPlugin {

    private static final int REQUEST_CODE_STORAGE = 100;
    private CallbackContext callbackContext;
    private Bitmap signatureBitmap;
    private Canvas canvas;
    private ImageView signatureView;
    private FrameLayout signatureLayout;
    private Path path;
    private Paint paint;

    // Variables para capturar datos biométricos
    private List<Map<String, Object>> biometricData = new ArrayList<>();
    private long lastTimestamp;
    private float lastX;
    private float lastY;

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) {
        if ("captureSignature".equals(action)) {
            this.callbackContext = callbackContext;
            Log.d("SignatureCapture", "Llamando a openSignatureScreen directamente para prueba.");
            openSignatureScreen();
            return true;
        }
        return false;
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        if (requestCode == REQUEST_CODE_STORAGE && grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            Log.d("SignatureCapture", "Permiso concedido, abriendo pantalla de firma");
            openSignatureScreen();
        } else {
            if (callbackContext != null) {
                callbackContext.error("Storage permission is required to save the signature.");
            }
        }
    }

    private void openSignatureScreen() {
        Log.d("SignatureCapture", "openSignatureScreen iniciado");

        // Establecer orientación horizontal antes de crear el layout
        cordova.getActivity().setRequestedOrientation(android.content.pm.ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE);

        cordova.getActivity().runOnUiThread(() -> {
            // Obtener las dimensiones de la pantalla exactas
            DisplayMetrics displayMetrics = new DisplayMetrics();
            cordova.getActivity().getWindowManager().getDefaultDisplay().getRealMetrics(displayMetrics);
            int width = displayMetrics.widthPixels;
            int height = displayMetrics.heightPixels;

            // Crear el contenedor de firma que ocupa toda la pantalla
            signatureLayout = new FrameLayout(cordova.getActivity());
            FrameLayout.LayoutParams layoutParams = new FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT);
            signatureLayout.setLayoutParams(layoutParams);

            // Crear ImageView para dibujar la firma ajustado al tamaño de la pantalla
            signatureView = new ImageView(cordova.getActivity());
            signatureView.setScaleType(ImageView.ScaleType.FIT_XY); // Forzar el escalado para cubrir todo
            signatureBitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
            canvas = new Canvas(signatureBitmap);
            canvas.drawColor(Color.WHITE); // Fondo blanco para el lienzo
            signatureView.setImageBitmap(signatureBitmap);

            // Ajustar el ImageView para que ocupe toda la pantalla
            FrameLayout.LayoutParams imageViewParams = new FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT);
            imageViewParams.gravity = Gravity.CENTER;
            signatureView.setLayoutParams(imageViewParams);
            signatureLayout.addView(signatureView);

            // Inicializar el Path y Paint para dibujar
            path = new Path();
            paint = new Paint();
            paint.setColor(Color.BLACK);
            paint.setStyle(Paint.Style.STROKE);
            paint.setStrokeWidth(5f);

            // Crear el botón de guardar
            Button saveButton = new Button(cordova.getActivity());
            saveButton.setText("Guardar Firma");
            saveButton.setOnClickListener(v -> saveSignature());
            FrameLayout.LayoutParams saveParams = new FrameLayout.LayoutParams(FrameLayout.LayoutParams.WRAP_CONTENT, FrameLayout.LayoutParams.WRAP_CONTENT);
            saveParams.gravity = Gravity.BOTTOM | Gravity.END;
            saveParams.setMargins(20, 20, 20, 20);
            saveButton.setLayoutParams(saveParams);
            signatureLayout.addView(saveButton);

            // Crear el botón de borrar
            Button clearButton = new Button(cordova.getActivity());
            clearButton.setText("Borrar");
            clearButton.setOnClickListener(v -> clearSignature());
            FrameLayout.LayoutParams clearParams = new FrameLayout.LayoutParams(FrameLayout.LayoutParams.WRAP_CONTENT, FrameLayout.LayoutParams.WRAP_CONTENT);
            clearParams.gravity = Gravity.BOTTOM | Gravity.START;
            clearParams.setMargins(20, 20, 20, 20);
            clearButton.setLayoutParams(clearParams);
            signatureLayout.addView(clearButton);

            // Crear el botón de cerrar (redondo con "X")
            Button closeButton = new Button(cordova.getActivity());
            closeButton.setText("X");
            closeButton.setTextSize(18); // Tamaño de la "X"
            closeButton.setBackgroundResource(android.R.color.transparent); // Fondo transparente

            // Establecer estilo de botón redondo
            closeButton.setWidth(100);
            closeButton.setHeight(100);
            closeButton.setBackgroundColor(Color.RED);
            closeButton.setTextColor(Color.WHITE);
            closeButton.setAllCaps(false); // Para mantener la "X" como está

            closeButton.setOnClickListener(v -> {
                cordova.getActivity().setRequestedOrientation(android.content.pm.ActivityInfo.SCREEN_ORIENTATION_PORTRAIT);
                resetScreen();  // Cierra la pantalla de firma sin guardar
            });
            FrameLayout.LayoutParams closeParams = new FrameLayout.LayoutParams(150, 150); // Tamaño del botón
            closeParams.gravity = Gravity.TOP | Gravity.END;
            closeParams.setMargins(20, 20, 20, 20);
            closeButton.setLayoutParams(closeParams);
            signatureLayout.addView(closeButton);

            // Configurar el toque para dibujar en el lienzo
            signatureView.setOnTouchListener((v, event) -> {
                float x = event.getX();
                float y = event.getY();
                long currentTimestamp = System.currentTimeMillis();
                float pressure = event.getPressure();

                Map<String, Object> pointData = new HashMap<>();
                pointData.put("x", x);
                pointData.put("y", y);
                pointData.put("pressure", pressure);
                pointData.put("timestamp", currentTimestamp);

                if (event.getAction() == MotionEvent.ACTION_DOWN) {
                    path.moveTo(x, y);
                    lastX = x;
                    lastY = y;
                    lastTimestamp = currentTimestamp;
                } else if (event.getAction() == MotionEvent.ACTION_MOVE) {
                    long timeDifference = currentTimestamp - lastTimestamp;
                    double distance = Math.sqrt(Math.pow(x - lastX, 2) + Math.pow(y - lastY, 2));
                    double speed = distance / timeDifference; // velocidad en px/ms

                    pointData.put("speed", speed);
                    lastTimestamp = currentTimestamp;
                    lastX = x;
                    lastY = y;

                    path.lineTo(x, y);
                    canvas.drawPath(path, paint);
                } else if (event.getAction() == MotionEvent.ACTION_UP) {
                    path.lineTo(x, y);
                    canvas.drawPath(path, paint);
                    path.reset();
                }

                biometricData.add(pointData);
                signatureView.invalidate();
                return true;
            });

            cordova.getActivity().setContentView(signatureLayout);
        });
    }

    // Método para guardar datos biométricos (opcional)
    private void saveBiometricData(List<Map<String, Object>> biometricData) {
        // Convertir `biometricData` a JSON y guardar o enviar a un servidor para análisis
        // Ejemplo de JSON:
        // [{"x": 10, "y": 20, "pressure": 0.5, "timestamp": 123456789, "speed": 0.1}, ...]
        try {
            JSONArray jsonArray = new JSONArray();
            for (Map<String, Object> dataPoint : biometricData) {
                JSONObject jsonObject = new JSONObject(dataPoint);
                jsonArray.put(jsonObject);
            }

            // Enviar los datos a JavaScript
            callbackContext.success(jsonArray);
        } catch (Exception e) {
            callbackContext.error("Error al procesar datos biométricos: " + e.getMessage());
        }

    }

    private void saveSignature() {
        try {
            // Guardar la firma en el almacenamiento interno con un nombre único
            String fileName = "firma_" + System.currentTimeMillis() + ".png";
            File path = new File(cordova.getContext().getFilesDir(), fileName);

            try (OutputStream out = new FileOutputStream(path)) {
                signatureBitmap.compress(Bitmap.CompressFormat.PNG, 100, out);
            }

            // Preparar los datos biométricos en formato JSON
            JSONArray jsonArray = new JSONArray();
            for (Map<String, Object> dataPoint : biometricData) {
                JSONObject jsonObject = new JSONObject(dataPoint);
                jsonArray.put(jsonObject);
            }

            // Enviar la ruta de la imagen y los datos biométricos a JavaScript
            JSONObject result = new JSONObject();
            result.put("imagePath", path.getAbsolutePath());
            result.put("biometricData", jsonArray);

            callbackContext.success(result);
        } catch (Exception e) {
            callbackContext.error("Error al guardar la firma: " + e.getMessage());
        } finally {
            // Cambiar la orientación a vertical después de guardar
            cordova.getActivity().setRequestedOrientation(android.content.pm.ActivityInfo.SCREEN_ORIENTATION_PORTRAIT);

            // Restablecer la pantalla
            resetScreen();
        }
    }

    private void clearSignature() {
        canvas.drawColor(Color.WHITE);
        signatureView.invalidate();
    }

    private void resetScreen() {
        cordova.getActivity().runOnUiThread(() -> {
            ((CordovaActivity) cordova.getActivity()).setContentView(webView.getView());
        });
    }
}