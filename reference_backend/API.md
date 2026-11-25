# REST API GemStore

Bază: `http://localhost:8080/api`. Cererile cu body folosesc `Content-Type: application/json`.
Răspunsurile de eroare sunt obiecte JSON: `{"error":"mesaj"}`.

| Metodă | Endpoint | Utilizare |
| --- | --- | --- |
| GET | `/health` | Verificarea serverului |
| GET | `/catalog` | Catalogul original plus starea utilizatorului |
| GET | `/products/{id}` | Datele canonice ale unui produs |
| GET | `/favorites` | Lista ID-urilor favorite |
| PUT | `/favorites/{id}` | Adăugare idempotentă la favorite |
| DELETE | `/favorites/{id}` | Eliminare din favorite |
| GET | `/products/{id}/reviews` | Recenziile produsului |
| POST | `/products/{id}/reviews` | Creare recenzie; răspuns 201 |
| DELETE | `/products/{id}/reviews/{reviewId}` | Ștergere recenzie creată în demo; răspuns 204 |
| GET | `/profile` | Profilul salvat |
| PUT | `/profile` | Salvarea profilului |
| GET | `/cart` | Linii și totaluri pe monedă |
| POST | `/cart/items` | Adăugare produs și variantă |
| PUT | `/cart/items/{lineId}` | Modificarea cantității |
| DELETE | `/cart/items/{lineId}` | Ștergerea liniei |
| DELETE | `/cart` | Golirea coșului |
| GET | `/orders` | Istoric de comenzi |
| POST | `/orders` | Plasarea comenzii; răspuns 201 |
| POST | `/orders/{id}/cancel` | Anularea unei comenzi |
| OPTIONS | orice rută | Preflight CORS |

## Exemple de body

Recenzie:

```json
{"author":"Valentin","text":"Produs bun","rating":5,"avatarUrl":""}
```

Profil:

```json
{"name":"Valentin","email":"test@example.com"}
```

Adăugare produs cu variantele definite în catalog:

```json
{"productId":"p003","quantity":1,"colorId":"black","size":"L"}
```

Pentru un produs fără variante, `colorId` și `size` sunt șiruri goale.
Modificarea cantității: `{"quantity":2}`. Cantitatea 0 elimină linia.

Checkout:

```json
{
  "requestId":"un-identificator-unic-stabil-la-reincercare",
  "customerName":"Valentin",
  "email":"test@example.com",
  "phone":"+37369123456",
  "address":"Chisinau, strada Exemplu 10",
  "notes":""
}
```

Clientul nu stabilește prețul sau totalul. Serverul preia aceste valori din catalog
și coș. La succes, comanda are `status: placed` și `paymentMethod: pay_on_delivery`,
iar coșul este golit. Reîncercările cu același `requestId` și același body returnează
aceeași comandă; schimbarea datelor folosind aceeași cheie produce 409.
O comandă anulată are `status: cancelled`.

## Erori

| Status | Semnificație |
| --- | --- |
| 400 | JSON/body invalid |
| 403 | Încercarea de a șterge o recenzie din catalog |
| 404 | Produs, linie, recenzie, comandă sau rută inexistentă |
| 409 | Conflict de comandă/identificator |
| 413 | Body mai mare de 64 KiB |
| 415 | Content-Type diferit de JSON |
| 422 | Date sau variante invalide, coș gol, cantitate invalidă |
| 500 | Eroare de salvare pe server |

Serverul este o implementare de laborator pentru un singur utilizator, fără
autentificare și fără procesare de plăți. Nu folosește date de catalog externe.
