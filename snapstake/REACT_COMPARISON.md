# Repository Pattern & State Management: Flutter vs React

## **Repository Pattern Comparison**

### **Flutter (Current Implementation)**
```dart
class BetsRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getUserBets(String userId) async {
    try {
      final response = await _client
          .from('bets')
          .select('*, moments(*)')
          .eq('user_id', userId)
          .order('placed_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error fetching user bets: $e');
      return [];
    }
  }
}
```

### **React (Equivalent Implementation)**
```javascript
// repositories/betsRepository.js
import { supabase } from '../config/supabase';

export class BetsRepository {
  async getUserBets(userId) {
    try {
      const { data, error } = await supabase
        .from('bets')
        .select('*, moments(*)')
        .eq('user_id', userId)
        .order('placed_at', { ascending: false });
      
      if (error) throw error;
      return data || [];
    } catch (error) {
      console.error('❌ Error fetching user bets:', error);
      return [];
    }
  }

  async placeBet({ momentId, userId, outcome, amount }) {
    try {
      const { data, error } = await supabase
        .from('bets')
        .insert({
          moment_id: momentId,
          user_id: userId,
          outcome,
          amount,
          status: 'active',
          placed_at: new Date().toISOString(),
        })
        .select()
        .single();
      
      if (error) throw error;
      return data;
    } catch (error) {
      console.error('❌ Error placing bet:', error);
      return null;
    }
  }
}

export const betsRepository = new BetsRepository();
```

---

## **State Management Comparison**

### **Flutter GetX (Current Implementation)**
```dart
class AuthController extends GetxController {
  final Rxn<User> user = Rxn<User>();
  final RxString userName = ''.obs;
  
  @override
  void onInit() {
    super.onInit();
    _loadUser();
  }

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
    user.value = null;
    userName.value = '';
  }
}

// Usage in Widget
class ProfilePage extends StatelessWidget {
  final AuthController authController = Get.find<AuthController>();
  
  @override
  Widget build(BuildContext context) {
    return Obx(() => Text(authController.userName.value));
  }
}
```

### **React Equivalent Options**

#### **1. Zustand (Closest to GetX)**
```javascript
// stores/authStore.js
import { create } from 'zustand';
import { supabase } from '../config/supabase';

export const useAuthStore = create((set, get) => ({
  user: null,
  userName: '',
  userEmail: '',
  
  loadUser: async () => {
    const { data: { user } } = await supabase.auth.getUser();
    if (user) {
      set({ 
        user, 
        userName: user.user_metadata?.full_name || '',
        userEmail: user.email 
      });
    }
  },

  signOut: async () => {
    await supabase.auth.signOut();
    set({ user: null, userName: '', userEmail: '' });
  },
}));

// Usage in Component
import { useAuthStore } from '../stores/authStore';

export const ProfilePage = () => {
  const { userName, userEmail, signOut } = useAuthStore();
  
  return (
    <div>
      <h1>{userName}</h1>
      <p>{userEmail}</p>
      <button onClick={signOut}>Sign Out</button>
    </div>
  );
};
```

#### **2. Redux Toolkit (More Verbose but Powerful)**
```javascript
// store/authSlice.js
import { createSlice, createAsyncThunk } from '@reduxjs/toolkit';
import { supabase } from '../config/supabase';

export const signOut = createAsyncThunk('auth/signOut', async () => {
  await supabase.auth.signOut();
});

const authSlice = createSlice({
  name: 'auth',
  initialState: {
    user: null,
    userName: '',
    loading: false,
  },
  reducers: {
    setUser: (state, action) => {
      state.user = action.payload;
      state.userName = action.payload?.user_metadata?.full_name || '';
    },
  },
  extraReducers: (builder) => {
    builder.addCase(signOut.fulfilled, (state) => {
      state.user = null;
      state.userName = '';
    });
  },
});

// Usage
import { useSelector, useDispatch } from 'react-redux';

export const ProfilePage = () => {
  const { userName } = useSelector((state) => state.auth);
  const dispatch = useDispatch();
  
  return (
    <div>
      <h1>{userName}</h1>
      <button onClick={() => dispatch(signOut())}>Sign Out</button>
    </div>
  );
};
```

#### **3. React Query + Context (Modern Approach)**
```javascript
// hooks/useAuth.js
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { supabase } from '../config/supabase';

export const useAuth = () => {
  const queryClient = useQueryClient();

  const { data: user, isLoading } = useQuery({
    queryKey: ['auth'],
    queryFn: async () => {
      const { data: { user } } = await supabase.auth.getUser();
      return user;
    },
  });

  const signOutMutation = useMutation({
    mutationFn: () => supabase.auth.signOut(),
    onSuccess: () => {
      queryClient.setQueryData(['auth'], null);
    },
  });

  return {
    user,
    userName: user?.user_metadata?.full_name || '',
    isLoading,
    signOut: signOutMutation.mutate,
  };
};

// Usage
export const ProfilePage = () => {
  const { userName, signOut } = useAuth();
  
  return (
    <div>
      <h1>{userName}</h1>
      <button onClick={signOut}>Sign Out</button>
    </div>
  );
};
```

---

## **Why Different Patterns Are Used**

### **Flutter/GetX Advantages:**
- **Built-in Reactivity**: `Obx()` automatically rebuilds when observables change
- **Minimal Boilerplate**: Simple `.obs` makes variables reactive
- **Lifecycle Management**: Controllers handle initialization/cleanup automatically
- **Type Safety**: Dart's strong typing catches errors at compile time

### **React Ecosystem Differences:**

#### **1. JavaScript/TypeScript Nature:**
```javascript
// JavaScript is more dynamic, less built-in reactivity
const [count, setCount] = useState(0); // Manual state updates

// vs Dart/GetX
final RxInt count = 0.obs; // Automatic reactivity
```

#### **2. Component-Based Architecture:**
```javascript
// React components re-render on state changes
function MyComponent() {
  const [data, setData] = useState(null);
  
  useEffect(() => {
    // Side effects in useEffect
    fetchData().then(setData);
  }, []);
  
  return <div>{data?.name}</div>; // Re-renders when data changes
}
```

#### **3. Ecosystem Choices:**
- **React Query/SWR**: For server state management
- **Zustand/Redux**: For client state management  
- **Context API**: For prop drilling avoidance
- **Custom Hooks**: For logic reuse

---

## **Converting SnapStake to React**

Here's how the current Flutter app would look in React:

```javascript
// hooks/useProfile.js
import { useQuery } from '@tanstack/react-query';
import { betsRepository } from '../repositories/betsRepository';
import { momentsRepository } from '../repositories/momentsRepository';
import { useAuth } from './useAuth';

export const useProfile = () => {
  const { user } = useAuth();

  const { data: bets = [], isLoading: betsLoading } = useQuery({
    queryKey: ['userBets', user?.id],
    queryFn: () => betsRepository.getUserBets(user.id),
    enabled: !!user?.id,
  });

  const { data: moments = [], isLoading: momentsLoading } = useQuery({
    queryKey: ['userMoments', user?.id],
    queryFn: () => momentsRepository.getUserMoments(user.id),
    enabled: !!user?.id,
  });

  const calculateStats = (bets, moments) => {
    const totalBets = bets.length;
    const wonBets = bets.filter(bet => bet.status === 'won').length;
    const winRate = totalBets > 0 ? (wonBets / totalBets) * 100 : 0;
    
    return { totalBets, wonBets, winRate };
  };

  return {
    bets,
    moments,
    stats: calculateStats(bets, moments),
    isLoading: betsLoading || momentsLoading,
  };
};

// ProfilePage.jsx
import { useProfile } from '../hooks/useProfile';

export const ProfilePage = () => {
  const { stats, bets, moments, isLoading } = useProfile();

  if (isLoading) return <div>Loading...</div>;

  return (
    <div className="profile-page">
      <div className="stats-header">
        <div className="stat-card">
          <span>{stats.totalBets}</span>
          <span>Total Bets</span>
        </div>
        <div className="stat-card">
          <span>{stats.winRate.toFixed(1)}%</span>
          <span>Win Rate</span>
        </div>
      </div>
      
      <div className="tabs">
        {/* Tab implementation */}
      </div>
    </div>
  );
};
```

---

## **Summary**

| Aspect | Flutter/GetX | React Ecosystem |
|--------|-------------|-----------------|
| **Repository Pattern** | ✅ Works great | ✅ Works great |
| **State Management** | GetX (built-in reactive) | Multiple options (Zustand, Redux, etc.) |
| **Reactivity** | Automatic with `.obs` | Manual with hooks/state |
| **Boilerplate** | Minimal | Varies by library |
| **Type Safety** | Built-in (Dart) | Optional (TypeScript) |
| **Learning Curve** | Single pattern | Multiple patterns to choose |

**The key difference**: Flutter/GetX provides a more opinionated, batteries-included approach, while React gives you flexibility to choose your preferred patterns and libraries.

Both approaches are valid - it's more about ecosystem conventions and developer preferences!
