# GraphQL API Examples

## Query Examples

### Get a Single Product

```graphql
query GetProduct($id: ID!) {
  product(id: $id) {
    id
    name
    description
    price
    averageRating
    totalReviews
    totalStock
    
    images {
      id
      url
      thumbnail
      webp
      webpThumbnail
      blurPlaceholder
    }
    
    variants {
      id
      name
      sku
      price
      stockQuantity
      active
    }
    
    categories {
      id
      name
      slug
    }
    
    tags {
      id
      name
    }
    
    seller {
      id
      name
      sellerTier
      level
    }
    
    reviews(first: 5) {
      edges {
        node {
          id
          rating
          comment
          createdAt
          reviewer {
            name
          }
          helpfulCount
        }
      }
    }
  }
}
```

Variables:
```json
{
  "id": "1"
}
```

---

### Search Products

```graphql
query SearchProducts($query: String!, $first: Int, $minPrice: Float, $maxPrice: Float) {
  searchProducts(query: $query, first: $first) {
    edges {
      node {
        id
        name
        price
        averageRating
        images {
          thumbnail
          webpThumbnail
        }
      }
    }
    pageInfo {
      hasNextPage
      endCursor
    }
  }
}
```

Variables:
```json
{
  "query": "laptop",
  "first": 20,
  "minPrice": 500,
  "maxPrice": 2000
}
```

---

### List Products with Filters

```graphql
query ListProducts(
  $first: Int
  $after: String
  $categoryId: ID
  $minPrice: Float
  $maxPrice: Float
  $sortBy: String
  $sortDirection: String
) {
  products(
    first: $first
    after: $after
    categoryId: $categoryId
    minPrice: $minPrice
    maxPrice: $maxPrice
    sortBy: $sortBy
    sortDirection: $sortDirection
  ) {
    edges {
      node {
        id
        name
        description
        price
        minPrice
        maxPrice
        totalStock
        
        images {
          thumbnail
          webpThumbnail
        }
        
        categories {
          name
        }
      }
      cursor
    }
    pageInfo {
      hasNextPage
      hasPreviousPage
      startCursor
      endCursor
    }
  }
}
```

Variables:
```json
{
  "first": 20,
  "categoryId": "1",
  "minPrice": 0,
  "maxPrice": 1000,
  "sortBy": "price",
  "sortDirection": "asc"
}
```

---

### Get Current User's Cart

```graphql
query GetCart {
  cart {
    id
    totalItems
    subtotal
    tax
    total
    
    items {
      id
      quantity
      unitPrice
      totalPrice
      
      product {
        id
        name
        images {
          thumbnail
          webpThumbnail
        }
      }
      
      variant {
        id
        name
        sku
      }
    }
  }
}
```

---

### Get Categories

```graphql
query GetCategories {
  categories {
    id
    name
    slug
    description
    productsCount
  }
}
```

---

## Mutation Examples

### Add to Cart

```graphql
mutation AddToCart($productId: ID!, $variantId: ID, $quantity: Int!) {
  addToCart(productId: $productId, variantId: $variantId, quantity: $quantity) {
    cart {
      id
      totalItems
      total
    }
    cartItem {
      id
      quantity
      product {
        name
      }
    }
    errors
  }
}
```

Variables:
```json
{
  "productId": "1",
  "variantId": "1",
  "quantity": 2
}
```

---

### Update Cart Item

```graphql
mutation UpdateCartItem($id: ID!, $quantity: Int!) {
  updateCartItem(id: $id, quantity: $quantity) {
    cartItem {
      id
      quantity
      totalPrice
    }
    errors
  }
}
```

Variables:
```json
{
  "id": "1",
  "quantity": 3
}
```

---

### Remove from Cart

```graphql
mutation RemoveFromCart($id: ID!) {
  removeFromCart(id: $id) {
    cart {
      id
      totalItems
      total
    }
    errors
  }
}
```

Variables:
```json
{
  "id": "1"
}
```

---

### Clear Cart

```graphql
mutation ClearCart {
  clearCart {
    cart {
      id
      totalItems
    }
    errors
  }
}
```

---

### Add to Wishlist

```graphql
mutation AddToWishlist($productId: ID!) {
  addToWishlist(productId: $productId) {
    wishlistItem {
      id
      product {
        name
      }
    }
    errors
  }
}
```

Variables:
```json
{
  "productId": "1"
}
```

---

### Create Review

```graphql
mutation CreateReview($productId: ID!, $rating: Int!, $comment: String) {
  createReview(productId: $productId, rating: $rating, comment: $comment) {
    review {
      id
      rating
      comment
      createdAt
    }
    errors
  }
}
```

Variables:
```json
{
  "productId": "1",
  "rating": 5,
  "comment": "Great product! Highly recommended."
}
```

---

## Subscription Examples

### Subscribe to Product Updates

```graphql
subscription ProductUpdated($id: ID!) {
  productUpdated(id: $id) {
    id
    name
    price
    totalStock
  }
}
```

Variables:
```json
{
  "id": "1"
}
```

---

### Subscribe to Inventory Changes

```graphql
subscription InventoryChanged($productId: ID!) {
  inventoryChanged(productId: $productId) {
    productId
    variantId
    stockQuantity
    available
    lowStock
    updatedAt
  }
}
```

Variables:
```json
{
  "productId": "1"
}
```

---

### Subscribe to Price Changes

```graphql
subscription PriceChanged($productId: ID!) {
  priceChanged(productId: $productId) {
    productId
    oldPrice
    newPrice
    discountPercentage
    reason
    updatedAt
  }
}
```

Variables:
```json
{
  "productId": "1"
}
```

---

## JavaScript Client Examples

### Using Fetch API

```javascript
// Query example
async function getProduct(productId) {
  const query = `
    query GetProduct($id: ID!) {
      product(id: $id) {
        id
        name
        price
        images {
          webp
          thumbnail
        }
      }
    }
  `;
  
  const response = await fetch('/graphql', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
    },
    body: JSON.stringify({
      query,
      variables: { id: productId }
    })
  });
  
  const { data, errors } = await response.json();
  
  if (errors) {
    console.error('GraphQL errors:', errors);
    return null;
  }
  
  return data.product;
}

// Mutation example
async function addToCart(productId, quantity = 1) {
  const mutation = `
    mutation AddToCart($productId: ID!, $quantity: Int!) {
      addToCart(productId: $productId, quantity: $quantity) {
        cart {
          totalItems
        }
        errors
      }
    }
  `;
  
  const response = await fetch('/graphql', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
    },
    body: JSON.stringify({
      query: mutation,
      variables: { productId, quantity }
    })
  });
  
  const { data, errors } = await response.json();
  
  if (errors || data.addToCart.errors.length > 0) {
    console.error('Errors:', errors || data.addToCart.errors);
    return false;
  }
  
  return true;
}
```

---

## Testing in GraphiQL

1. Start your Rails server: `bin/rails server`
2. Visit `http://localhost:3000/graphiql` (development only)
3. Copy and paste any query/mutation from above
4. Add variables in the "Query Variables" panel
5. Click the "Play" button to execute

---

## Performance Tips

1. **Request only what you need** - Don't fetch unnecessary fields
2. **Use fragments** - Reuse common field selections
3. **Paginate large lists** - Use `first` and `after` arguments
4. **Batch queries** - Combine multiple queries in one request
5. **Use persisted queries** - Cache frequently used queries
6. **Monitor complexity** - Keep queries under complexity limit (300)
7. **Use DataLoader** - Automatic N+1 prevention

---

## Rate Limits

- **General**: 100 requests per minute per user
- **Anonymous**: 50 requests per minute per IP
- **Exceeded**: Returns 429 status with `Retry-After` header

