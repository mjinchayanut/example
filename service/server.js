import express from 'express';
import cors from 'cors';
import { MongoClient, ObjectId } from 'mongodb';

const app = express();
const PORT = process.env.PORT || 3000;

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/product_db';
let db;

app.use(cors());
app.use(express.json());

async function connectToMongoDB() {
  try {
    const client = new MongoClient(MONGODB_URI);
    await client.connect();
    db = client.db('product_db');
    console.log('Connected to MongoDB');
    
    // Create sample data if collection is empty
    const productsCollection = db.collection('products');
    const count = await productsCollection.countDocuments();
    
    if (count === 0) {
      await createSampleData();
    }
  } catch (error) {
    console.error('MongoDB connection error:', error);
  }
}

// Create sample data
async function createSampleData() {
  const sampleProducts = [
    {
      barcode: '1234567890123',
      serial: 'SN001',
      name: 'iPhone 15 Pro',
      brand: 'Apple',
      category: 'Smartphone',
      price: 39900,
      description: 'Latest iPhone with A17 Pro chip',
      stock: 50,
      createdAt: new Date()
    },
    {
      barcode: '2345678901234',
      serial: 'SN002',
      name: 'Samsung Galaxy S24',
      brand: 'Samsung',
      category: 'Smartphone',
      price: 29900,
      description: 'Flagship Android phone',
      stock: 30,
      createdAt: new Date()
    },
    {
      barcode: '3456789012345',
      serial: 'SN003',
      name: 'MacBook Air M3',
      brand: 'Apple',
      category: 'Laptop',
      price: 42900,
      description: 'Ultra-thin laptop with M3 chip',
      stock: 20,
      createdAt: new Date()
    }
  ];
  
  await db.collection('products').insertMany(sampleProducts);
  console.log('Sample data created');
}

app.get('/api/product/:identifier', async (req, res) => {
  try {
    const { identifier } = req.params;
    const productsCollection = db.collection('products');
    
    const product = await productsCollection.findOne({
      $or: [
        { barcode: identifier },
        { serial: identifier }
      ]
    });
    
    if (!product) {
      return res.status(404).json({ 
        success: false, 
        message: 'Product not found' 
      });
    }
    
    res.json({ 
      success: true, 
      data: product 
    });
  } catch (error) {
    res.status(500).json({ 
      success: false, 
      message: 'Server error', 
      error: error.message 
    });
  }
});

app.post('/api/product', async (req, res) => {
  try {
    const { barcode, serial, name, brand, category, price, description, stock } = req.body;
    
    // Validate required fields
    if (!barcode || !serial || !name || !price) {
      return res.status(400).json({
        success: false,
        message: 'Missing required fields: barcode, serial, name, price'
      });
    }
    
    const productsCollection = db.collection('products');
    
    const existingProduct = await productsCollection.findOne({
      $or: [
        { barcode: barcode },
        { serial: serial }
      ]
    });
    
    if (existingProduct) {
      return res.status(409).json({
        success: false,
        message: 'Product with this barcode or serial already exists'
      });
    }
    
    const newProduct = {
      barcode,
      serial,
      name,
      brand: brand || '',
      category: category || '',
      price: parseFloat(price),
      description: description || '',
      stock: parseInt(stock) || 0,
      createdAt: new Date(),
      updatedAt: new Date()
    };
    
    const result = await productsCollection.insertOne(newProduct);
    
    res.status(201).json({
      success: true,
      message: 'Product added successfully',
      data: { ...newProduct, _id: result.insertedId }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
});

app.get('/api/products', async (req, res) => {
  try {
    const { page = 1, limit = 10, search = '' } = req.query;
    const productsCollection = db.collection('products');
    
    const query = search ? {
      $or: [
        { name: { $regex: search, $options: 'i' } },
        { brand: { $regex: search, $options: 'i' } },
        { category: { $regex: search, $options: 'i' } },
        { barcode: { $regex: search, $options: 'i' } },
        { serial: { $regex: search, $options: 'i' } }
      ]
    } : {};
    
    const skip = (parseInt(page) - 1) * parseInt(limit);
    
    const products = await productsCollection
      .find(query)
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit))
      .toArray();
    
    const total = await productsCollection.countDocuments(query);
    
    res.json({
      success: true,
      data: products,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        pages: Math.ceil(total / parseInt(limit))
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
});

app.put('/api/product/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const updateData = { ...req.body, updatedAt: new Date() };
    
    const productsCollection = db.collection('products');
    const result = await productsCollection.updateOne(
      { _id: new ObjectId(id) },
      { $set: updateData }
    );
    
    if (result.matchedCount === 0) {
      return res.status(404).json({
        success: false,
        message: 'Product not found'
      });
    }
    
    res.json({
      success: true,
      message: 'Product updated successfully'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
});

app.delete('/api/product/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const productsCollection = db.collection('products');
    
    const result = await productsCollection.deleteOne({ _id: new ObjectId(id) });
    
    if (result.deletedCount === 0) {
      return res.status(404).json({
        success: false,
        message: 'Product not found'
      });
    }
    
    res.json({
      success: true,
      message: 'Product deleted successfully'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
});

app.get('/api/health', (req, res) => {
  res.json({ 
    success: true, 
    message: 'Server is running',
    timestamp: new Date().toISOString()
  });
});

connectToMongoDB().then(() => {
  app.listen(PORT, () => {
    console.log(`Server is running on port ${PORT}`);
    console.log(`API endpoints:`);
    console.log(`- GET /api/health - Health check`);
    console.log(`- GET /api/product/:identifier - Get product by barcode/serial`);
    console.log(`- POST /api/product - Add new product`);
    console.log(`- GET /api/products - Get all products with pagination`);
    console.log(`- PUT /api/product/:id - Update product`);
    console.log(`- DELETE /api/product/:id - Delete product`);
  });
});

console.log('\n=== Testing API ===');
console.log('Testing health endpoint...');

setTimeout(async () => {
  try {
    const response = await fetch('http://localhost:3000/api/health');
    const data = await response.json();
    console.log('Health check:', data);
    
    console.log('\nTesting product lookup...');
    const productResponse = await fetch('http://localhost:3000/api/product/1234567890123');
    const productData = await productResponse.json();
    console.log('Product lookup result:', productData);
    
  } catch (error) {
    console.log('API test error (this is normal if MongoDB is not connected):', error.message);
  }
}, 2000);